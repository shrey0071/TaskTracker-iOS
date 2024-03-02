import SwiftUI
import UserNotifications

struct Task: Identifiable, Codable {
    var id = UUID()
    var name: String
    var description: String
    var progress: Float
    var isCompleted: Bool
    var reminder: Date?
}

struct ContentView: View {
    @AppStorage("tasks") var tasksData: Data = Data()
    @State private var tasks = [Task]()
    @State private var newTaskName = ""
    @State private var newTaskDescription = ""
    @State private var selectedTaskIndex: Int?
    @State private var showingTaskDetails = false
    @State private var showingSetReminderAlert = false
    @State private var reminderDate = Date()

    var body: some View {
        NavigationView {
            VStack {
                Spacer().frame(height: 20)
                List {
                    ForEach(tasks.indices, id: \.self) { index in
                        NavigationLink(destination: TaskDetailsView(task: $tasks[index], onClose: { showingTaskDetails = false })) {
                            TaskRow(task: tasks[index])
                        }
                    }
                    .onDelete(perform: deleteTask)
                }
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("Task Tracker")
                .navigationBarItems(trailing:
                    HStack {
                        EditButton()
                        Button(action: {
                            newTaskName = ""
                            newTaskDescription = ""
                            selectedTaskIndex = nil
                            showingTaskDetails = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.blue)
                        }
                    }
                )
                Spacer()
            }
            .frame(maxHeight: .infinity)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showingTaskDetails) {
            if let index = selectedTaskIndex {
                TaskDetailsView(task: $tasks[index], onClose: { showingTaskDetails = false })
            } else {
                NewTaskView(newTaskName: $newTaskName, newTaskDescription: $newTaskDescription, onSave: { name, description, reminder in
                    tasks.append(Task(name: name, description: description, progress: 0, isCompleted: false, reminder: reminder))
                    showingTaskDetails = false
                    scheduleNotification(for: tasks.last!)
                    saveTasks() // Save tasks when a new task is added
                })
            }
        }
        .onAppear {
            async {
                await askAuthForNotification()
                loadTasks() // Load tasks when the app appears
            }
        }
    }

    private func deleteTask(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
        saveTasks() // Save tasks when a task is deleted
    }

    private func saveTasks() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(tasks)
            tasksData = data // Save tasks data to UserDefaults
        } catch {
            print("Error encoding tasks: \(error)")
        }
    }

    private func loadTasks() {
        do {
            let decoder = JSONDecoder()
            tasks = try decoder.decode([Task].self, from: tasksData) // Load tasks data from UserDefaults
        } catch {
            print("Error decoding tasks: \(error)")
        }
    }
}

private func askAuthForNotification() async {
    let center = UNUserNotificationCenter.current()
    do {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
        // Handle the error here.
    }
}

private func scheduleNotification(for task: Task) {
    guard let reminderDate = task.reminder else { return }
    let content = UNMutableNotificationContent()
    content.title = "Task Reminder"
    content.body = "Don't forget to complete \(task.name)"
    content.sound = UNNotificationSound.default

    let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate), repeats: false)

    let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}

struct TaskRow: View {
    var task: Task

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(task.name)
                    .font(.headline)
                Text(task.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                ProgressBar(value: task.progress)
                    .frame(height: 8)
                    .padding(.bottom, 4)
                if let reminder = task.reminder {
                    Text("Reminder: \(formattedDate(reminder))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(task.isCompleted ? "Completed" : "In Progress")
                    .foregroundColor(task.isCompleted ? .green : .blue)
                    .font(.caption)
            }
            Spacer()
            if task.reminder != nil {
                Image(systemName: "bell")
                    .foregroundColor(.blue)
            }
            if task.isCompleted {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
            }
        }
    }
}

struct TaskDetailsView: View {
    @Binding var task: Task
    var onClose: () -> Void
    @State private var showingReminderDatePicker = false
    @State private var selectedReminderDate: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(task.name)
                .font(.title)
                .padding(.bottom)

            Text("Description:")
                .font(.headline)
                .padding(.bottom, 2)
            Text(task.description)
                .foregroundColor(.gray)

            if let reminder = task.reminder {
                HStack {
                    Text("Reminder:")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text(formattedDate(reminder))
                    Spacer()
                }
                .padding(.bottom, 10)
                .opacity(0.8)
                .onTapGesture {
                    showingReminderDatePicker = true
                }
            } else {
                Button(action: {
                    showingReminderDatePicker = true
                }) {
                    Text("Set Reminder")
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
                .padding(.bottom, 10)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                if showingReminderDatePicker {
                    HStack(spacing: 20) {
                        Button(action: {
                            task.reminder = selectedReminderDate
                            showingReminderDatePicker = false
                            scheduleNotification(for: task)
                        }) {
                            Text("Update")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        Button(action: {
                            task.reminder = nil
                            showingReminderDatePicker = false
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
                        }) {
                            Text("Delete")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.bottom)
                    
                    DatePicker("Select Reminder Date", selection: $selectedReminderDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(WheelDatePickerStyle())
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.bottom)
                }
            }

            HStack {
                Spacer()
                Button(action: {
                    task.isCompleted.toggle()
                    if task.isCompleted {
                        task.progress = 1
                    } else {
                        task.progress = 0
                    }
                    onClose()
                }) {
                    Text(task.isCompleted ? "Mark as Incomplete" : "Mark as Complete")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(15)
        .padding()
    }
}

private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

struct NewTaskView: View {
    @Binding var newTaskName: String
    @Binding var newTaskDescription: String
    @State private var selectedReminderDate = Date()
    @State private var isSettingReminder = false
    var onSave: (String, String, Date?) -> Void

    var body: some View {
        VStack {
            TextField("Enter task name", text: $newTaskName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .cornerRadius(8)
            TextField("Enter task description", text: $newTaskDescription)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .cornerRadius(8)

            if isSettingReminder {
                DatePicker("Set Reminder", selection: $selectedReminderDate, displayedComponents: [.date, .hourAndMinute])
                    .padding()
            }

            Button(action: {
                if isSettingReminder {
                    onSave(newTaskName, newTaskDescription, selectedReminderDate)
                } else {
                    isSettingReminder = true
                }
            }) {
                Text(isSettingReminder ? "Save Task" : "Set Reminder")
                    .foregroundColor(.white)
                    .padding()
                    .background(isSettingReminder ? Color.blue : Color.gray)
                    .cornerRadius(8)
            }
            .padding()
        }
        .padding()
    }
}

struct ProgressBar: View {
    var value: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(Color.gray)

                Rectangle()
                    .frame(width: min(CGFloat(value) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(Color.blue)
            }
            .cornerRadius(45.0)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .preferredColorScheme(.light)
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
