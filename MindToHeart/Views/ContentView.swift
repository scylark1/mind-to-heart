import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Thought.date, order: .reverse) private var thoughts: [Thought]

    @State private var recorder = AudioRecorder()
    @State private var phase: Phase = .idle
    @State private var selectedDay: Date?
    @State private var showingCalendar = false
    @State private var showingSettings = false
    @State private var showingNewThought = false
    @State private var errorMessage: String?

    enum Phase {
        case idle, recording, transcribing, polishing
    }

    private var isBusy: Bool {
        phase == .transcribing || phase == .polishing
    }

    private var filteredThoughts: [Thought] {
        guard let selectedDay else { return thoughts }
        return thoughts.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredThoughts.isEmpty {
                    emptyView
                } else {
                    thoughtList
                }
            }
            .navigationTitle(selectedDay.map { $0.formatted(.dateTime.month().day()) } ?? "随想")
            .navigationDestination(for: Thought.self) { thought in
                ThoughtDetailView(thought: thought)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if selectedDay != nil {
                        Button("全部") { selectedDay = nil }
                    }
                    Button {
                        showingCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                recordBar
            }
            .sheet(isPresented: $showingCalendar) {
                CalendarSheet(selectedDay: $selectedDay)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingNewThought) {
                NewThoughtSheet(date: dateForNewThought()) { text, photos, date, polish in
                    Task { await saveTypedThought(text, photos: photos, date: date, polish: polish) }
                }
            }
            .alert("出错了", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 列表

    /// 每条随想单独一个卡片
    private var thoughtList: some View {
        List {
            ForEach(filteredThoughts) { thought in
                Section {
                    NavigationLink(value: thought) {
                        ThoughtRow(thought: thought)
                    }
                    .swipeActions {
                        Button("删除", systemImage: "trash", role: .destructive) {
                            modelContext.delete(thought)
                        }
                    }
                }
            }
        }
        .listSectionSpacing(12)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            selectedDay == nil ? "还没有随想" : "这一天没有记录",
            systemImage: "text.bubble",
            description: Text("点下面的麦克风说出你的想法，或者点键盘打字")
        )
    }

    // MARK: - 录音

    private var recordBar: some View {
        VStack(spacing: 8) {
            if let statusText {
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 48) {
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(phase == .recording ? Color.red : Color.accentColor)
                            .frame(width: 72, height: 72)
                        if isBusy {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: phase == .recording ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .disabled(isBusy)

                Button {
                    showingNewThought = true
                } label: {
                    Image(systemName: "keyboard")
                        .font(.title)
                        .frame(width: 72, height: 72)
                        .background(Color(.secondarySystemFill), in: Circle())
                }
                .disabled(phase != .idle)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.bar)
    }

    /// 只在录音和处理中显示
    private var statusText: String? {
        switch phase {
        case .idle:
            return nil
        case .recording:
            return "录音中 " + Duration.seconds(recorder.elapsed).formatted(.time(pattern: .minuteSecond))
        case .transcribing:
            return "正在转文字…"
        case .polishing:
            return "正在润色…"
        }
    }

    private func toggleRecording() {
        Task {
            if phase == .recording {
                await finishRecording()
            } else {
                await startRecording()
            }
        }
    }

    private func startRecording() async {
        guard OpenAIService.fromSettings().hasAPIKey else {
            showingSettings = true
            return
        }
        guard await AudioRecorder.requestPermission() else {
            errorMessage = "需要麦克风权限，请到「设置 > 隐私与安全性 > 麦克风」中开启"
            return
        }
        do {
            try recorder.start()
            phase = .recording
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishRecording() async {
        let duration = recorder.elapsed
        guard let fileURL = recorder.stop() else {
            phase = .idle
            return
        }
        defer { try? FileManager.default.removeItem(at: fileURL) }

        guard duration >= 1 else {
            phase = .idle
            errorMessage = "录音太短了"
            return
        }

        let service = OpenAIService.fromSettings()

        // 1. 转文字，先把原文存下来，润色失败也不会丢
        phase = .transcribing
        let thought: Thought
        do {
            let rawText = try await service.transcribe(fileURL: fileURL)
            guard !rawText.isEmpty else {
                phase = .idle
                errorMessage = "没有识别到说话内容"
                return
            }
            thought = Thought(date: dateForNewThought(), rawText: rawText)
            modelContext.insert(thought)
        } catch {
            phase = .idle
            errorMessage = error.localizedDescription
            return
        }

        // 2. 润色
        phase = .polishing
        do {
            thought.polishedAttributedText = try await service.polish(thought.rawAttributedText)
        } catch {
            errorMessage = "原文已保存，但润色失败：\(error.localizedDescription)"
        }
        phase = .idle
    }

    /// 保存手动输入的随想，需要时再润色
    private func saveTypedThought(_ text: NSAttributedString, photos: [Data], date: Date, polish: Bool) async {
        let thought = Thought(date: date, rawText: text.string)
        thought.rawAttributedText = text
        modelContext.insert(thought)
        for data in photos {
            let photo = ThoughtPhoto(data: data)
            modelContext.insert(photo)
            photo.thought = thought
        }
        guard polish, text.length > 0 else { return }

        phase = .polishing
        do {
            thought.polishedAttributedText = try await OpenAIService.fromSettings().polish(text)
        } catch {
            errorMessage = "原文已保存，但润色失败：\(error.localizedDescription)"
        }
        phase = .idle
    }

    /// 正在查看某一天时，新录的随想记到那一天（时间用当前时间）
    private func dateForNewThought() -> Date {
        guard let selectedDay, !Calendar.current.isDateInToday(selectedDay) else { return .now }
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: .now)
        return calendar.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: selectedDay
        ) ?? selectedDay
    }
}

private struct ThoughtRow: View {
    let thought: Thought

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !thought.displayText.isEmpty {
                    Text(thought.displayText)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            let photos = thought.sortedPhotos
            if let first = photos.first {
                PhotoThumbnail(data: first.data, size: 56)
                    .overlay(alignment: .bottomTrailing) {
                        if photos.count > 1 {
                            Text("\(photos.count)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .background(.black.opacity(0.5), in: Capsule())
                                .padding(4)
                        }
                    }
            }
        }
        .padding(.vertical, 4)
    }

    /// 今年的不显示年份
    private var dateText: String {
        let isThisYear = Calendar.current.isDate(thought.date, equalTo: .now, toGranularity: .year)
        let format: Date.FormatStyle = isThisYear
            ? .dateTime.month().day().weekday().hour().minute()
            : .dateTime.year().month().day().weekday().hour().minute()
        return thought.date.formatted(format)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Thought.self, inMemory: true)
}
