import SwiftUI
import SideNotesCore

struct EditorView: View {
    @ObservedObject var viewModel: PlanViewModel
    @State private var newGroupTitle = ""
    @State private var newAreaTitle = ""
    @State private var archiveQuery = ""
    @State private var isArchiveConfirmationPresented = false

    var body: some View {
        TabView(selection: $viewModel.editorTab) {
            todayEditor
                .tabItem { Text("今天") }
                .tag(EditorTab.today)
            longTermEditor
                .tabItem { Text("长期") }
                .tag(EditorTab.longTerm)
            archiveBrowser
                .tabItem { Text("历史") }
                .tag(EditorTab.archives)
            appearanceEditor
                .tabItem { Text("外观") }
                .tag(EditorTab.appearance)
        }
        .padding()
        .frame(minWidth: 760, minHeight: 560)
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

    private var todayEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("新分组，例如 工作 / 早上 / 英语", text: $newGroupTitle)
                    .textFieldStyle(.roundedBorder)
                Button("添加分组") {
                    viewModel.addDailyGroup(title: newGroupTitle)
                    newGroupTitle = ""
                }
            }

            if viewModel.dailyPlan.groups.isEmpty {
                ContentUnavailableView("还没有当天计划", systemImage: "checklist", description: Text("添加自定义分组后，再为每组添加任务。"))
            } else {
                List {
                    let groups = viewModel.dailyPlan.groups.sorted { $0.sortOrder < $1.sortOrder }
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        DailyGroupEditor(
                            group: group,
                            index: index,
                            groupCount: groups.count,
                            viewModel: viewModel
                        )
                    }
                }
            }

            HStack {
                Button("归档并进入下一天") {
                    isArchiveConfirmationPresented = true
                }
                .disabled(viewModel.dailyPlan.groups.isEmpty)
                Spacer()
                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
    }

    private var longTermEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("新长期领域，例如 读书 / 英语 / 社交", text: $newAreaTitle)
                    .textFieldStyle(.roundedBorder)
                Button("添加领域") {
                    viewModel.addLongTermArea(title: newAreaTitle)
                    newAreaTitle = ""
                }
            }

            if viewModel.longTermAreas.isEmpty {
                ContentUnavailableView("还没有长期计划", systemImage: "rectangle.stack", description: Text("添加长期领域和事项，它们会显示在卡片背面。"))
            } else {
                List {
                    let areas = viewModel.longTermAreas.sorted { $0.sortOrder < $1.sortOrder }
                    ForEach(Array(areas.enumerated()), id: \.element.id) { index, area in
                        LongTermAreaEditor(
                            area: area,
                            index: index,
                            areaCount: areas.count,
                            viewModel: viewModel
                        )
                    }
                }
            }
        }
    }

    private var archiveBrowser: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("搜索历史任务或分组", text: $archiveQuery)
                .textFieldStyle(.roundedBorder)
                .onChange(of: archiveQuery) { _, newValue in
                    viewModel.searchArchives(newValue)
                }

            if viewModel.archiveSearchResults.isEmpty {
                ContentUnavailableView("没有历史归档", systemImage: "archivebox", description: Text("归档当天计划后，会在这里回看和搜索。"))
            } else {
                List(viewModel.archiveSearchResults) { archive in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(archive.archiveDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.headline)
                        ForEach(archive.groupsSnapshot) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.title)
                                    .font(.subheadline.weight(.semibold))
                                ForEach(group.tasks) { task in
                                    HStack {
                                        Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                                        Text(task.title)
                                            .strikethrough(task.isCompleted)
                                    }
                                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var appearanceEditor: some View {
        Form {
            Section("悬浮卡片") {
                VStack(alignment: .leading) {
                    Text("透明度 \(viewModel.settings.cardOpacity, specifier: "%.2f")")
                    Slider(
                        value: Binding(
                            get: { viewModel.settings.cardOpacity },
                            set: { viewModel.setCardOpacity($0) }
                        ),
                        in: 0.35...1
                    )
                }

                VStack(alignment: .leading) {
                    Text("圆角 \(viewModel.settings.cardCornerRadius, specifier: "%.0f")")
                    Slider(
                        value: Binding(
                            get: { viewModel.settings.cardCornerRadius },
                            set: { viewModel.setCardCornerRadius($0) }
                        ),
                        in: 4...48
                    )
                }
            }
        }
    }
}

private struct DailyGroupEditor: View {
    let group: DailyPlanGroup
    let index: Int
    let groupCount: Int
    @ObservedObject var viewModel: PlanViewModel
    @State private var newTaskTitle = ""
    @State private var groupTitle = ""

    var body: some View {
        Section {
            let tasks = group.tasks.sorted { $0.sortOrder < $1.sortOrder }
            ForEach(Array(tasks.enumerated()), id: \.element.id) { taskIndex, task in
                DailyTaskEditor(
                    task: task,
                    index: taskIndex,
                    taskCount: tasks.count,
                    viewModel: viewModel
                )
            }

            HStack {
                TextField("新任务", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                Button("添加任务") {
                    viewModel.addDailyTask(groupID: group.id, title: newTaskTitle)
                    newTaskTitle = ""
                }
            }
        } header: {
            HStack {
                TextField("分组名称", text: $groupTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.renameDailyGroup(id: group.id, title: groupTitle) }
                    .onAppear { groupTitle = group.title }
                    .onChange(of: group.title) { _, newValue in groupTitle = newValue }

                Button("保存") {
                    viewModel.renameDailyGroup(id: group.id, title: groupTitle)
                }
                Button("上移") {
                    viewModel.moveDailyGroup(id: group.id, toSortOrder: max(0, index - 1))
                }
                .disabled(index == 0)
                Button("下移") {
                    viewModel.moveDailyGroup(id: group.id, toSortOrder: min(groupCount - 1, index + 1))
                }
                .disabled(index >= groupCount - 1)
                Button("删除", role: .destructive) {
                    viewModel.deleteDailyGroup(id: group.id)
                }
            }
        }
    }
}

private struct DailyTaskEditor: View {
    let task: DailyTask
    let index: Int
    let taskCount: Int
    @ObservedObject var viewModel: PlanViewModel
    @State private var title = ""

    var body: some View {
        HStack {
            Button {
                viewModel.toggleTask(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
            }
            .buttonStyle(.plain)

            TextField("任务", text: $title)
                .textFieldStyle(.roundedBorder)
                .strikethrough(task.isCompleted)
                .onSubmit { viewModel.renameDailyTask(id: task.id, title: title) }
                .onAppear { title = task.title }
                .onChange(of: task.title) { _, newValue in title = newValue }

            Button("保存") {
                viewModel.renameDailyTask(id: task.id, title: title)
            }
            Button("上移") {
                viewModel.moveDailyTask(id: task.id, toSortOrder: max(0, index - 1))
            }
            .disabled(index == 0)
            Button("下移") {
                viewModel.moveDailyTask(id: task.id, toSortOrder: min(taskCount - 1, index + 1))
            }
            .disabled(index >= taskCount - 1)
            Button("删除", role: .destructive) {
                viewModel.deleteDailyTask(id: task.id)
            }
        }
    }
}

private struct LongTermAreaEditor: View {
    let area: LongTermArea
    let index: Int
    let areaCount: Int
    @ObservedObject var viewModel: PlanViewModel
    @State private var newItemTitle = ""
    @State private var areaTitle = ""

    var body: some View {
        Section {
            let items = area.items.sorted { $0.sortOrder < $1.sortOrder }
            ForEach(Array(items.enumerated()), id: \.element.id) { itemIndex, item in
                LongTermItemEditor(
                    item: item,
                    index: itemIndex,
                    itemCount: items.count,
                    viewModel: viewModel
                )
            }

            HStack {
                TextField("新长期事项", text: $newItemTitle)
                    .textFieldStyle(.roundedBorder)
                Button("添加事项") {
                    viewModel.addLongTermItem(areaID: area.id, title: newItemTitle)
                    newItemTitle = ""
                }
            }
        } header: {
            HStack {
                TextField("领域名称", text: $areaTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.renameLongTermArea(id: area.id, title: areaTitle) }
                    .onAppear { areaTitle = area.title }
                    .onChange(of: area.title) { _, newValue in areaTitle = newValue }

                Button("保存") {
                    viewModel.renameLongTermArea(id: area.id, title: areaTitle)
                }
                Button("上移") {
                    viewModel.moveLongTermArea(id: area.id, toSortOrder: max(0, index - 1))
                }
                .disabled(index == 0)
                Button("下移") {
                    viewModel.moveLongTermArea(id: area.id, toSortOrder: min(areaCount - 1, index + 1))
                }
                .disabled(index >= areaCount - 1)
                Button("删除", role: .destructive) {
                    viewModel.deleteLongTermArea(id: area.id)
                }
            }
        }
    }
}

private struct LongTermItemEditor: View {
    let item: LongTermItem
    let index: Int
    let itemCount: Int
    @ObservedObject var viewModel: PlanViewModel
    @State private var title = ""

    var body: some View {
        HStack {
            TextField("长期事项", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit { viewModel.renameLongTermItem(id: item.id, title: title) }
                .onAppear { title = item.title }
                .onChange(of: item.title) { _, newValue in title = newValue }

            Button("保存") {
                viewModel.renameLongTermItem(id: item.id, title: title)
            }
            Button("上移") {
                viewModel.moveLongTermItem(id: item.id, toSortOrder: max(0, index - 1))
            }
            .disabled(index == 0)
            Button("下移") {
                viewModel.moveLongTermItem(id: item.id, toSortOrder: min(itemCount - 1, index + 1))
            }
            .disabled(index >= itemCount - 1)
            Button("删除", role: .destructive) {
                viewModel.deleteLongTermItem(id: item.id)
            }
        }
    }
}
