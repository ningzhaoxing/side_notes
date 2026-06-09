import SwiftUI
import SideNotesCore

struct PlanCardView: View {
    @ObservedObject var viewModel: PlanViewModel
    var onPinToggle: (Bool) -> Void
    var onEdit: () -> Void
    var onSettings: () -> Void
    var onQuit: () -> Void
    var onResize: (CGSize) -> Void
    @State private var isArchiveConfirmationPresented = false
    @State private var resizeStartSize: CGSize?
    @State private var newGroupTitle = ""
    @State private var newAreaTitle = ""

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
        HStack(spacing: 6) {
            Text(viewModel.settings.visibleSide == .front ? "今天" : "长期")
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 8)
            toolbarButton(
                systemName: viewModel.settings.isPinned ? "pin.slash" : "pin",
                label: viewModel.settings.isPinned ? "取消固定" : "固定"
            ) {
                let next = !viewModel.settings.isPinned
                viewModel.setPinned(next)
                onPinToggle(viewModel.settings.isPinned)
            }
            toolbarButton(systemName: "arrow.triangle.2.circlepath", label: "翻面") {
                viewModel.flipCard()
            }
            toolbarButton(systemName: "pencil", label: "编辑") {
                onEdit()
            }
            toolbarButton(systemName: "gearshape", label: "设置") {
                onSettings()
            }
            toolbarButton(systemName: "power", label: "退出") {
                onQuit()
            }
            toolbarButton(
                systemName: "archivebox",
                label: "归档",
                isDisabled: viewModel.dailyPlan.groups.isEmpty
            ) {
                isArchiveConfirmationPresented = true
            }
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.055))
    }

    private func toolbarButton(
        systemName: String,
        label: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .disabled(isDisabled)
        .help(label)
        .accessibilityLabel(label)
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
                InlineAddRow(
                    placeholder: "新分组，例如 工作 / 早上 / 英语",
                    buttonTitle: "添加分组",
                    text: $newGroupTitle
                ) {
                    if viewModel.addDailyGroup(title: newGroupTitle) {
                        newGroupTitle = ""
                    }
                }

                if viewModel.dailyPlan.groups.isEmpty {
                    emptyState(title: "今天还没有计划", detail: "先添加一个分组，再直接写任务。")
                } else {
                    ForEach(viewModel.dailyPlan.groups.sorted { $0.sortOrder < $1.sortOrder }) { group in
                        InlineDailyGroupView(group: group, viewModel: viewModel)
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
                InlineAddRow(
                    placeholder: "新长期领域，例如 读书 / 英语 / 社交",
                    buttonTitle: "添加领域",
                    text: $newAreaTitle
                ) {
                    if viewModel.addLongTermArea(title: newAreaTitle) {
                        newAreaTitle = ""
                    }
                }

                if viewModel.longTermAreas.isEmpty {
                    emptyState(title: "还没有长期领域", detail: "先添加一个领域，再直接写长期事项。")
                } else {
                    ForEach(viewModel.longTermAreas.sorted { $0.sortOrder < $1.sortOrder }) { area in
                        InlineLongTermAreaView(area: area, viewModel: viewModel)
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

private struct InlineAddRow: View {
    let placeholder: String
    let buttonTitle: String
    @Binding var text: String
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onAdd)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help(buttonTitle)
            .accessibilityLabel(buttonTitle)
        }
    }
}

private struct InlineDailyGroupView: View {
    let group: DailyPlanGroup
    @ObservedObject var viewModel: PlanViewModel
    @State private var title = ""
    @State private var newTaskTitle = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("分组名称", text: $title)
                    .font(.subheadline.weight(.semibold))
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .onSubmit(saveTitle)
                    .onChange(of: isTitleFocused) { _, isFocused in
                        if !isFocused { saveTitle() }
                    }
                    .onAppear { title = group.title }
                    .onChange(of: group.title) { _, newValue in title = newValue }

                Button(role: .destructive) {
                    viewModel.deleteDailyGroup(id: group.id)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help("删除分组")
                .accessibilityLabel("删除分组")
            }

            ForEach(group.tasks.sorted { $0.sortOrder < $1.sortOrder }) { task in
                InlineDailyTaskView(task: task, viewModel: viewModel)
            }

            InlineAddRow(
                placeholder: "新任务",
                buttonTitle: "添加任务",
                text: $newTaskTitle
            ) {
                if viewModel.addDailyTask(groupID: group.id, title: newTaskTitle) {
                    newTaskTitle = ""
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func saveTitle() {
        if !viewModel.renameDailyGroup(id: group.id, title: title) {
            title = group.title
        }
    }
}

private struct InlineDailyTaskView: View {
    let task: DailyTask
    @ObservedObject var viewModel: PlanViewModel
    @State private var title = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                viewModel.toggleTask(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "标记未完成" : "标记完成")

            TextField("任务", text: $title)
                .textFieldStyle(.plain)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .focused($isTitleFocused)
                .onSubmit(saveTitle)
                .onChange(of: isTitleFocused) { _, isFocused in
                    if !isFocused { saveTitle() }
                }
                .onAppear { title = task.title }
                .onChange(of: task.title) { _, newValue in title = newValue }

            Button(role: .destructive) {
                viewModel.deleteDailyTask(id: task.id)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("删除任务")
            .accessibilityLabel("删除任务")
        }
    }

    private func saveTitle() {
        if !viewModel.renameDailyTask(id: task.id, title: title) {
            title = task.title
        }
    }
}

private struct InlineLongTermAreaView: View {
    let area: LongTermArea
    @ObservedObject var viewModel: PlanViewModel
    @State private var title = ""
    @State private var newItemTitle = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("领域名称", text: $title)
                    .font(.subheadline.weight(.semibold))
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .onSubmit(saveTitle)
                    .onChange(of: isTitleFocused) { _, isFocused in
                        if !isFocused { saveTitle() }
                    }
                    .onAppear { title = area.title }
                    .onChange(of: area.title) { _, newValue in title = newValue }

                Button(role: .destructive) {
                    viewModel.deleteLongTermArea(id: area.id)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help("删除领域")
                .accessibilityLabel("删除领域")
            }

            ForEach(area.items.sorted { $0.sortOrder < $1.sortOrder }) { item in
                InlineLongTermItemView(item: item, viewModel: viewModel)
            }

            InlineAddRow(
                placeholder: "新长期事项",
                buttonTitle: "添加事项",
                text: $newItemTitle
            ) {
                if viewModel.addLongTermItem(areaID: area.id, title: newItemTitle) {
                    newItemTitle = ""
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func saveTitle() {
        if !viewModel.renameLongTermArea(id: area.id, title: title) {
            title = area.title
        }
    }
}

private struct InlineLongTermItemView: View {
    let item: LongTermItem
    @ObservedObject var viewModel: PlanViewModel
    @State private var title = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(Color.accentColor.opacity(0.72))
                .frame(width: 6, height: 6)

            TextField("长期事项", text: $title)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .onSubmit(saveTitle)
                .onChange(of: isTitleFocused) { _, isFocused in
                    if !isFocused { saveTitle() }
                }
                .onAppear { title = item.title }
                .onChange(of: item.title) { _, newValue in title = newValue }

            Button(role: .destructive) {
                viewModel.deleteLongTermItem(id: item.id)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("删除事项")
            .accessibilityLabel("删除事项")
        }
    }

    private func saveTitle() {
        if !viewModel.renameLongTermItem(id: item.id, title: title) {
            title = item.title
        }
    }
}
