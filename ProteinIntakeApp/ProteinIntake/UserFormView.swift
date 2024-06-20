//
//  UserFormView.swift
//  ProteinIntake
//
//  Created by Eddie Diaz on 12/10/23.
//

import SwiftUI

struct UserFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataModel: DataModel
    
    @State private var heightFeet: Int = 0
    @State private var heightInches: Int = 0
    @State private var weight: Int = 0
    @State private var hasActiveJob: Bool = false
    @State private var trainsAtGym: Bool = false
    @State private var trainingFrequency: Int = 1
    @State private var sex: String = "Male"
    @State private var isPregnant: Bool = false
    @State private var trainingGoal: String = "Muscle gain"
    @State private var mealsPerDay: Int = 1
    
    @FocusState private var isInputActive: Bool
    
    let sexes = ["Male", "Female"]
    let trainingGoals = ["Muscle gain", "Fat loss", "Maintenance"]
    let feetRange = 3...7
    let inchesRange = 0...11
    
    // if the app detects a saved profile in UserDefaults, it will load up that information into the form
    init() {
            if let savedProfile = UserDefaults.standard.object(forKey: "UserProfile") as? [String: Any] {
                _heightFeet = State(initialValue: savedProfile["heightFeet"] as? Int ?? 0)
                _heightInches = State(initialValue: savedProfile["heightInches"] as? Int ?? 0)
                _weight = State(initialValue: savedProfile["weight"] as? Int ?? 0)
                _hasActiveJob = State(initialValue: savedProfile["hasActiveJob"] as? Bool ?? false)
                _trainsAtGym = State(initialValue: savedProfile["trainsAtGym"] as? Bool ?? false)
                _trainingFrequency = State(initialValue: savedProfile["trainingFrequency"] as? Int ?? 1)
                _sex = State(initialValue: savedProfile["sex"] as? String ?? "Male")
                _isPregnant = State(initialValue: (savedProfile["sex"] as? String == "Female") && (savedProfile["isPregnant"] as? Bool ?? false))
                _trainingGoal = State(initialValue: savedProfile["trainingGoal"] as? String ?? "Muscle gain")
                _mealsPerDay = State(initialValue: savedProfile["mealsPerDay"] as? Int ?? 1)
            } 
            // otherwise, load defaults
            else {
                _heightFeet = State(initialValue: 0)
                _heightInches = State(initialValue: 0)
                _weight = State(initialValue: 0)
                _hasActiveJob = State(initialValue: false)
                _trainsAtGym = State(initialValue: false)
                _trainingFrequency = State(initialValue: 1)
                _sex = State(initialValue: "Male")
                _isPregnant = State(initialValue: false)
                _trainingGoal = State(initialValue: "Muscle gain")
                _mealsPerDay = State(initialValue: 1)
            }
        }
    
    // User form with needed information
    var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Height")) {
                        Picker("Feet", selection: $heightFeet) {
                            ForEach(feetRange, id: \.self) { feet in
                                Text("\(feet) ft").tag(feet)
                            }
                        }

                        Picker("Inches", selection: $heightInches) {
                            ForEach(inchesRange, id: \.self) { inches in
                                Text("\(inches) in").tag(inches)
                            }
                        }
                    }
                    
                    // actual text input needs to be formated and limited to numbers only
                    Section(header: Text("Weight")) {
                            TextField(
                                "Weight (lbs)",
                                value: $weight,
                                formatter: NumberFormatter()
                            )
                            .keyboardType(.numberPad) // keyboard type to number pad
                            .focused($isInputActive)  // Bind focus state to your TextField
                            .toolbar { // Add a toolbar with a Done button
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        isInputActive = false // Dismiss keyboard when done
                                    }
                                }
                            }
                        }
                    
                    Section(header: Text("Sex")) {
                        Picker("Sex", selection: $sex) {
                            ForEach(sexes, id: \.self) { sexOption in
                                Text(sexOption).tag(sexOption)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        if sex == "Female" {
                            Toggle("Are you pregnant?", isOn: $isPregnant)
                        }
                    }
                    
                    Section(header: Text("Physical Activity")){
                        Toggle("Do you work an active job?", isOn: $hasActiveJob)
                        
                        Toggle("Do you train at a gym or other athletic practice?", isOn: $trainsAtGym)
                        
                        if trainsAtGym {
                            Stepper("Training frequency per week: \(trainingFrequency)", value: $trainingFrequency, in: 1...7)
                        }
                    }
                    
                    Section(header: Text("Lifestyle")) {
                        Picker("Training Goal", selection: $trainingGoal) {
                            ForEach(trainingGoals, id: \.self) {
                                Text($0)
                            }
                        }

                        Stepper("Meals per day: \(mealsPerDay)", value: $mealsPerDay, in: 1...5)
                    }
                }
                .navigationTitle("User Profile")
                .navigationBarItems(
                    leading: Button("Cancel") { dismiss() },
                    trailing: Button("Submit") { saveUserProfile(); dismiss() }
                        .disabled(!isFormValid())
                )
            }
        }
    
    // Implement the UITextFieldDelegate method to handle the return key
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder() // Dismiss the keyboard
            return true
        }
    
    // check for completed form
    private func isFormValid() -> Bool {
        return weight > 0 && (heightFeet > 0 || heightInches > 0) && trainingFrequency >= 1 && trainingFrequency <= 7 && mealsPerDay >= 1 && mealsPerDay <= 5
    }
    
    // Save profile on submit to user defaults for continued use
        private func saveUserProfile() {
            let userProfileDict: [String: Any] = [
                "heightFeet": heightFeet,
                "heightInches": heightInches,
                "weight": weight,
                "hasActiveJob": hasActiveJob,
                "trainsAtGym": trainsAtGym,
                "trainingFrequency": trainingFrequency,
                "sex": sex,
                "isPregnant": isPregnant,
                "trainingGoal": trainingGoal,
                "mealsPerDay": mealsPerDay
            ]
            
            UserDefaults.standard.set(userProfileDict, forKey: "UserProfile")
            // Update the userProfile in dataModel with the new data
                dataModel.userProfile = UserProfile(from: userProfileDict)
                dataModel.fetchData() // update steps and activity data
            // Trigger the protein intake calculation and server sending here
            dataModel.sendDataToServer { predictedClass in
                dataModel.calculateProteinIntake(predictedClass: predictedClass) { dailyIntake in
                    self.dataModel.dailyProteinIntake = dailyIntake
                }
            }
                dismiss()
        }
}

struct UserFormView_Previews: PreviewProvider {
    static var previews: some View {
        UserFormView()
    }
}
