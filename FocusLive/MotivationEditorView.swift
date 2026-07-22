//
//  MotivationEditorView.swift
//  FocusLive
//

import SwiftUI

struct MotivationEditorView: View {
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quote: String
    @State private var author: String

    init(initialQuote: String, initialAuthor: String, onSave: @escaping (String, String) -> Void) {
        self.onSave = onSave
        _quote = State(initialValue: initialQuote)
        _author = State(initialValue: initialAuthor)
    }

    private var trimmedQuote: String {
        quote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("鼓励内容") {
                    ZStack(alignment: .topLeading) {
                        if trimmedQuote.isEmpty {
                            Text("写一句想留给自己的鼓励...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }

                        TextEditor(text: $quote)
                            .frame(minHeight: 150)
                    }
                }

                Section("作者（可选）") {
                    TextField("作者（可选）", text: $author)
                }
            }
            .navigationTitle("自定义鼓励")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存鼓励") {
                        onSave(trimmedQuote, author)
                        dismiss()
                    }
                    .disabled(trimmedQuote.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
