import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var items: [SavedItem]

    @State private var provider = AppSettings.provider
    @State private var apiKeyInput = ""
    @State private var keySaved = false
    @State private var models: [String] = []
    @State private var selectedModel = ""
    @State private var isFetchingModels = false

    @State private var loginService: WebService?
    @State private var loginVersion = 0   // bump to re-read login state
    @State private var backendURL = AppSettings.backendURL ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section("AI 제공자") {
                    Picker("제공자", selection: $provider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: provider) { _, newValue in
                        AppSettings.provider = newValue
                        configure(for: newValue)
                    }
                }

                Section {
                    SecureField(provider.keyPlaceholder, text: $apiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("키 저장") { saveKey() }
                        .disabled(apiKeyInput.isEmpty)
                    if keySaved {
                        Label("키 저장됨", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.footnote)
                    }
                } header: {
                    Text("\(provider.displayName) API 키")
                } footer: {
                    Text("키는 기기 Keychain에 제공자별로 분리 저장됩니다. \(provider.consoleHint)")
                }

                Section {
                    Picker("모델", selection: $selectedModel) {
                        ForEach(models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: selectedModel) { _, newValue in
                        guard !newValue.isEmpty else { return }
                        AppSettings.setModel(newValue, for: provider)
                    }

                    Button {
                        Task { await refreshModels() }
                    } label: {
                        if isFetchingModels {
                            HStack { ProgressView(); Text("불러오는 중…") }
                        } else {
                            Label("지원 모델 목록 가져오기", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(isFetchingModels || !keySaved)
                } header: {
                    Text("모델")
                } footer: {
                    Text(keySaved
                         ? "키 계정에서 실제 사용 가능한 모델을 불러옵니다."
                         : "키를 저장하면 지원 모델 전체를 불러올 수 있어요. (지금은 기본 목록)")
                }

                Section {
                    TextField("https://...vercel.app", text: $backendURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("저장") {
                        AppSettings.backendURL = backendURL.trimmingCharacters(in: .whitespaces)
                    }
                    .disabled(backendURL.trimmingCharacters(in: .whitespaces).isEmpty
                              && (AppSettings.backendURL ?? "").isEmpty)
                } header: {
                    Text("YouTube 백엔드 URL")
                } footer: {
                    Text("yt-dlp 백엔드를 배포한 주소(backend 폴더). 입력하면 유튜브 자막·전체 스크립트·구간 미리보기를 안정적으로 가져옵니다.")
                }

                Section {
                    ForEach(WebService.allCases) { service in
                        serviceRow(service)
                    }
                } header: {
                    Text("서비스 로그인")
                } footer: {
                    Text("로그인하면 해당 서비스 콘텐츠를 가져옵니다(유튜브는 위 백엔드 방식을 권장). 세션 쿠키는 기기 Keychain에만 저장됩니다.")
                }

                Section("보관함") {
                    LabeledContent("저장된 항목", value: "\(items.count)개")
                    LabeledContent("분석 완료", value: "\(items.filter { $0.status == .done }.count)개")
                }
            }
            .navigationTitle("설정")
            .onAppear { configure(for: provider) }
            .sheet(item: $loginService) { service in
                LoginSheet(service: service) { loginVersion += 1 }
            }
        }
    }

    @ViewBuilder
    private func serviceRow(_ service: WebService) -> some View {
        let _ = loginVersion   // re-evaluate when login state changes
        HStack {
            Label(service.displayName, systemImage: service.symbolName)
            Spacer()
            if !service.isAvailable {
                Text("준비 중").font(.footnote).foregroundStyle(.secondary)
            } else if CookieStore.isLoggedIn(service) {
                Text("로그인됨").font(.footnote).foregroundStyle(.green)
                Button("로그아웃") {
                    CookieStore.setCookieHeader(nil, for: service)
                    loginVersion += 1
                }
                .font(.footnote)
            } else {
                Button("로그인") { loginService = service }
                    .font(.footnote)
            }
        }
    }

    /// Load the stored key state + model list for a provider when it's selected.
    private func configure(for provider: LLMProvider) {
        apiKeyInput = ""
        keySaved = KeychainStore.apiKey(for: provider)?.isEmpty == false
        models = provider.fallbackModels
        let saved = AppSettings.model(for: provider)
        selectedModel = models.contains(saved) ? saved : (models.first ?? saved)
        if keySaved {
            Task { await refreshModels() }
        }
    }

    private func saveKey() {
        KeychainStore.setAPIKey(apiKeyInput, for: provider)
        apiKeyInput = ""
        keySaved = true
        Task { await refreshModels() }
    }

    private func refreshModels() async {
        isFetchingModels = true
        defer { isFetchingModels = false }
        let key = KeychainStore.apiKey(for: provider)
        let fetched = await ModelCatalog.models(for: provider, apiKey: key)
        models = fetched
        let saved = AppSettings.model(for: provider)
        if fetched.contains(saved) {
            selectedModel = saved
        } else if let first = fetched.first {
            selectedModel = first
            AppSettings.setModel(first, for: provider)
        }
    }
}
