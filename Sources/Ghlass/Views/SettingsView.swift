import SwiftUI

struct SettingsView: View {
    @Binding var githubToken: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading) {
                Text("GitHub Personal Access Token")
                    .font(.headline)
                
                SecureField("Enter your token", text: $githubToken)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                Text("Generate a token with 'notifications' scope at github.com/settings/tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .glassEffect()
            
            Button(action: {
                GitHubService.shared.token = githubToken
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Save")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(40)
        .frame(width: 500, height: 300)
        .liquidBackground()
    }
}
