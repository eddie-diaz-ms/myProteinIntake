//
//  ContentView.swift
//  ProteinIntake
//
//  Created by Eddie Diaz on 12/9/23.
//

import SwiftUI

struct ContentView: View {
    // Labels will be updated with data from the model
    @State private var dailyIntakeLabel = "Calculating..."
    @State private var mealIntakeLabel = "Unknown"
    @State private var mealLabel = "Unknown"
    
    // State variable to control the presentation of the form
    @State private var showingUserForm = false
    
    @StateObject var dataModel = DataModel()
    
    // Method to update the daily intake label
        func updateDailyIntake(dailyIntake: Double) {
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 0
            if let formattedString = formatter.string(from: NSNumber(value: dailyIntake)) {
                dailyIntakeLabel = "\(formattedString) g"
            }
        }
    
    let learnMoreURL = URL(string: "https://www.mayoclinichealthsystem.org/hometown-health/speaking-of-health/are-you-getting-too-much-protein")!
    
    var body: some View {
        ZStack {
            // Background color
            Color.blue.edgesIgnoringSafeArea(.all)
            
            // Main content
            VStack {
                // Title
                Text("My Protein Intake")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 60)
                
                // Declare mealIntakeValue outside the if block
                let mealIntakeValue = dataModel.userProfile != nil ? dataModel.proteinIntakePerMeal : 0
                
                // Check if userProfile exists
                if let userProfile = dataModel.userProfile {
                    
                    // Circle container for daily intake
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Daily Requirement:")
                            .foregroundColor(.black)
                            .fontWeight(.medium)
                            .padding(.leading, 30)
                            .padding(.bottom, 5)
                        Text("\(dataModel.dailyProteinIntake, specifier: "%.2f") g")
                            .font(.system(size: 50))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(width: 300, height: 300)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 20)
                    .padding(.vertical, 20)
                    // Rectangle containers for meal intake and number of meals with black text color
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Per Meal:")
                                .foregroundColor(.black)
                                .padding([.leading, .top])
                                .padding(.bottom, 5)
                            Text("\(mealIntakeValue, specifier: "%.2f") g")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                        
                        VStack(alignment: .leading) {
                            Text("Meals:")
                                .foregroundColor(.black)
                                .padding([.leading, .top])
                                .padding(.bottom, 5)
                            Text("\(userProfile.mealsPerDay) per day")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                } else {
                    // Show message if userProfile is nil
                    Text("Please create a user profile.")
                        .multilineTextAlignment(.center)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(width: 300, height: 300)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                        .padding(.vertical, 20)
                }
                if mealIntakeValue >= 40 {
                    // Bottom warning container
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 25, height: 25)
                            .foregroundColor(.white)
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Your protein servings are maxed out. Please consider using a protein supplement between meals to satisfy daily intake.")
                                .foregroundColor(.white)
                                .font(.footnote)
                                .multilineTextAlignment(.leading)
                            
                            Button(action: {
                                // Open the URL when the hyperlink is tapped
                                UIApplication.shared.open(learnMoreURL)
                            }) {
                                Text("Learn More")
                                    .font(.footnote)
                                    .underline()
                                    .foregroundColor(.white)
                                    .padding(.leading, 200)
                            }
                        }
                    }
                    .padding()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                    
                    Spacer()
                } else {}
            }
        }
        .overlay(
            // User button positioned on the top right corner
            HStack {
                Spacer()
                Button(action: {
                    // Toggle the state to show the forn
                    showingUserForm = true
                }) {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.white)
                        .padding(.trailing, 40)
                }
            }, alignment: .topTrailing
        )
        .sheet(isPresented: $showingUserForm) {
                    // Pass the observed dataModel to the form view
                    UserFormView().environmentObject(dataModel)
                }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
