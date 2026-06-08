import SwiftUI
import SideNotesCore

struct EditorView: View {
    @ObservedObject var viewModel: PlanViewModel
    @State private var newGroupTitle = ""
    @State private var newAreaTitle = ""
    @State private var archiveQuery = ""

    var body: some View {
        TabView {
            todayEditor
                .tabItem { Text("今天") }
            longTermEditor
                .tabItem { Text("长期") }
            archiveBrowser
                .tabItem { Text("历史") }
            appearanceEditor
                .tabItem { Text("外观") }
        }
        .padding()
        .frame(minWidth: 760, minHeight: 560)
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
                    ForEach(viewModel.dailyPlan.groups.sorted { $0.sortOrder < $1.sortOrder }) { group in
                        DailyGroupEditor(group: group, viewModel: viewModel)
                    }
                }
            }

            HStack {
                Button("归档并进入下一天") {
                    viewModel.archiveCurrentPlan()
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
                    ForEach(viewModel.longTermAreas.sorted { $0.sortOrder < $1.sortOrder }) { area in
                        LongTermAreaEditor(area: area, viewModel: viewModel)
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
    @ObservedObject var viewModel: PlanViewModel
    @State private var newTaskTitle = ""

    var body: some View {
        Section(group.title) {
            ForEach(group.tasks.sorted { $0.sortOrder < $1.sortOrder }) { task in
                Button {
                    viewModel.toggleTask(task)
                } label: {
                    HStack {
                        Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        Text(task.title)
                            .strikethrough(task.isCompleted)
                    }
                }
                .buttonStyle(.plain)
            }

            HStack {
                TextField("新任务", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                Button("添加任务") {
                    viewModel.addDailyTask(groupID: group.id, title: newTaskTitle)
                    newTaskTitle = ""
                }
            }
        }
    }
}

private struct LongTermAreaEditor: View {
    let area: LongTermArea
    @ObservedObject var viewModel: PlanViewModel
    @State private var newItemTitle = ""

    var body: some View {
        Section(area.title) {
            ForEach(area.items.sorted { $0.sortOrder < $1.sortOrder }) { item in
                Text(item.title)
            }

            HStack {
                TextField("新长期事项", text: $newItemTitle)
                    .textFieldStyle(.roundedBorder)
                Button("添加事项") {
                    viewModel.addLongTermItem(areaID: area.id, title: newItemTitle)
                    newItemTitle = ""
                }
            }
        }
    }
}
