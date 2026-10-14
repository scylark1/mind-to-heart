import SwiftUI

/// 选择某一天，只看那天的随想
struct CalendarSheet: View {
    @Binding var selectedDay: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("选择日期", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
                Spacer()
            }
            .navigationTitle("按日期查看")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("显示全部") {
                        selectedDay = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("查看") {
                        selectedDay = date
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let selectedDay { date = selectedDay }
        }
        .presentationDetents([.medium, .large])
    }
}
