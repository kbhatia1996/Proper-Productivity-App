import SwiftUI

/// Root screen once a pigeon belongs to a nest: today's tasks plus the Activity calendar.
struct MainTabView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @StateObject private var taskViewModel = TaskViewModel()
    
    var body: some View {
        TabView {
            DashboardView(taskViewModel: taskViewModel)
                .tabItem { Label("Home", systemImage: "house.fill") }
            
            FitnessCalendarView(taskViewModel: taskViewModel, firebaseService: firebaseService)
                .tabItem { Label("Activity", systemImage: "calendar") }
        }
        .tint(SoloLevellingTheme.brightGold)
    }
}
