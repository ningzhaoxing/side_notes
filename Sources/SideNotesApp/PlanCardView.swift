import SwiftUI
import SideNotesCore

struct PlanCardView: View {
    @ObservedObject var viewModel: PlanViewModel
    var onPinToggle: (Bool) -> Void
    var onEdit: () -> Void
    var onSettings: () -> Void
    var onResize: (CGSize) -> Void
    @State private var isArchiveConfirmationPresented = false
    @State private var resizeStartSize: CGSize?

    var body: some View {
        VStack(spacing: 0) {
            controls

            ZStack {
                if viewModel.settings.visibleSide == .front {
                    frontSide
                        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                } else {
                    backSide
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.settings.visibleSide)
        }
        .overlay(alignment: .bottomTrailing) {
            resizeHandle
        }
        .frame(width: viewModel.settings.cardFrame.width, height: viewModel.settings.cardFrame.height)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: viewModel.settings.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: viewModel.settings.cardCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 26, x: 0, y: 18)
        .opacity(viewModel.settings.cardOpacity)
        .confirmationDialog(
            "归档当前计划？",
            isPresented: $isArchiveConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("归档并进入下一天", role: .destructive) {
                viewModel.archiveCurrentPlan()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前计划会保存到历史归档，然后清空当天计划。")
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Text(viewModel.settings.visibleSide == .front ? "今天" : "长期")
                .font(.headline)
            Spacer()
            Button(viewModel.settings.isPinned ? "取消固定" : "固定") {
                let next = !viewModel.settings.isPinned
                viewModel.setPinned(next)
                onPinToggle(next)
            }
            Button("翻面") {
                viewModel.flipCard()
            }
            Button("编辑") {
                onEdit()
            }
            Button("设置") {
                onSettings()
            }
            Button("归档") {
                isArchiveConfirmationPresented = true
            }
            .disabled(viewModel.dailyPlan.groups.isEmpty)
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.055))
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .padding(6)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let start = resizeStartSize ?? CGSize(
                            width: viewModel.settings.cardFrame.width,
                            height: viewModel.settings.cardFrame.height
                        )
                        if resizeStartSize == nil {
                            resizeStartSize = start
                        }
                        onResize(CGSize(
                            width: start.width + value.translation.width,
                            height: start.height + value.translation.height
                        ))
                    }
                    .onEnded { _ in
                        resizeStartSize = nil
                    }
            )
            .help("拖动调整卡片大小")
    }

    private var frontSide: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.dailyPlan.groups.isEmpty {
                    emptyState(title: "今天还没有计划", detail: "打开编辑窗口，添加自定义分组和任务。")
                } else {
                    ForEach(viewModel.dailyPlan.groups.sorted { $0.sortOrder < $1.sortOrder }) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(group.tasks.sorted { $0.sortOrder < $1.sortOrder }) { task in
                                Button {
                                    viewModel.toggleTask(task)
                                } label: {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(task.isCompleted ? .green : .secondary)
                                        Text(task.title)
                                            .strikethrough(task.isCompleted)
                                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(18)
        }
    }

    private var backSide: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.longTermAreas.isEmpty {
                    emptyState(title: "还没有长期领域", detail: "打开编辑窗口，添加读书、英语、社交等长期计划。")
                } else {
                    ForEach(viewModel.longTermAreas.sorted { $0.sortOrder < $1.sortOrder }) { area in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(area.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(area.items.sorted { $0.sortOrder < $1.sortOrder }) { item in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.72))
                                        .frame(width: 6, height: 6)
                                    Text(item.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(18)
        }
    }

    private func emptyState(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
}
