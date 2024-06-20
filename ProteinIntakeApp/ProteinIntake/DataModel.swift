//
//  DataModel.swift
//  ProteinIntake
//
//  Created by Eddie Diaz on 12/10/23.
//

import Foundation
import CoreMotion
import CoreML

class DataModel: ObservableObject {
    var averageSteps: Double = 0
    var frequencyRun: Int = 0
    var frequencyBike: Int = 0
    
    @Published var userProfile: UserProfile?
    @Published var dailyProteinIntake: Double = 0

    private let pedometer = CMPedometer()
    private let activityManager = CMMotionActivityManager()
    
    // Function to fetch CoreMotion data
    func fetchData() {
        fetchStepCountData()
        calculateActivityFrequencies()
    }
    
    // calculate average steps from the last week
    private func fetchStepCountData() {
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!

        pedometer.queryPedometerData(from: sevenDaysAgo, to: now) { [weak self] (data, error) in
            guard let self = self, error == nil, let data = data else { return }
            self.averageSteps = data.numberOfSteps.doubleValue / 7.0
        }
    }
    
    // function to fetch activity data
    func calculateActivityFrequencies() {
            guard CMMotionActivityManager.isActivityAvailable() else {
                print("Motion activity not available")
                return
            }

            let calendar = Calendar.current
            let now = Date()
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!

            activityManager.queryActivityStarting(from: sevenDaysAgo, to: now, to: .main) { [weak self] (activities, error) in
                guard let self = self, error == nil, let activities = activities else { return }

                // call function to count running activities
                let runningDays = self.countDaysWithActivity(activities, activityType: .running)
                self.frequencyRun = runningDays

                // call function to count cycling activities
                let bikingDays = self.countDaysWithActivity(activities, activityType: .cycling)
                self.frequencyBike = bikingDays
            }
        }
        
        // count separate instances of running or cycling in the past week
        private func countDaysWithActivity(_ activities: [CMMotionActivity], activityType: ActivityType) -> Int {
            let filteredActivities = activities.filter { activity in
                switch activityType {
                case .running:
                    return activity.running
                case .cycling:
                    return activity.cycling
                }
            }

            let uniqueDays = Set(filteredActivities.map { activity in
                return Calendar.current.startOfDay(for: activity.startDate)
            })

            return uniqueDays.count
        }
        
        // activities of interest
        enum ActivityType {
            case running, cycling
        }
    
    // use height and weight data to calculate BMI
    func calculateBMI(heightFeet: Int, heightInches: Int, weight: Int) -> Double {
        let totalInches = Double(heightFeet * 12 + heightInches)
        let heightInMeters = totalInches * 0.0254
        let weightInKg = Double(weight) * 0.453592
        let bmi = weightInKg / (heightInMeters * heightInMeters)
        return bmi
    }
    
    // Baseline protein intake based on predicted class
    // Reference: https://examine.com/guides/protein-intake/
    func getBaselineProteinIntake(predictedClass: Int) -> Double {
        switch predictedClass {
        case 0: // Sedentary
            return 1.2
        case 1: // Low active
            return 1.4
        case 2: // Somewhat active
            return 1.6
        case 3: // Active
            return 1.8
        case 4: // Very active
            return 2.0
        default:
            return 1.2 // Default case
        }
    }
    
    // adjust baseline intake for BMI
    // overweight --> less, underweight --> more
    func adjustForBMI(bmi: Double, baselineIntake: Double) -> Double {
        if bmi < 18.5 {
            return baselineIntake * 1.2
        } else if bmi >= 25 {
            return baselineIntake * 0.8
        } else {
            return baselineIntake
        }
    }
    
    // adjust for gender, note logic for pregnancy
    // https://pubmed.ncbi.nlm.nih.gov/11706282/
    func adjustForGender(isFemale: Bool, isPregnant: Bool, adjustedIntake: Double) -> Double {
        if isFemale {
            return isPregnant ? max(adjustedIntake, 1.8) : adjustedIntake * 0.8
        } else {
            return adjustedIntake
        }
    }
    
    // adjust intake for training goal
    func adjustForTrainingGoal(goal: String, genderAdjustedIntake: Double) -> Double {
        switch goal {
        case "Muscle gain":
            return genderAdjustedIntake * 1.2
        case "Fat loss":
            return genderAdjustedIntake * 0.8
        default:
            return genderAdjustedIntake
        }
    }
    
    func calculateProteinIntake(predictedClass: Int, completion: @escaping (Double) -> Void) {
        guard let userProfile = userProfile else { return }
        
        // base from prediction
        let baselineIntake = getBaselineProteinIntake(predictedClass: predictedClass)
        
        // consider bmi for healthier servings
        let bmi = calculateBMI(heightFeet: userProfile.heightFeet, heightInches: userProfile.heightInches, weight: userProfile.weight)
        let bmiAdjustedIntake = adjustForBMI(bmi: bmi, baselineIntake: baselineIntake)
        
        // Men need about 20% more protein, unless women are pregnant
        let genderAdjustedIntake = adjustForGender(isFemale: userProfile.sex == "Female", isPregnant: userProfile.isPregnant, adjustedIntake: bmiAdjustedIntake)
        
        // adjust for reported goals
        let finalIntake = adjustForTrainingGoal(goal: userProfile.trainingGoal, genderAdjustedIntake: genderAdjustedIntake)
        
        // multiply times weight
        let weightInKg = Double(userProfile.weight ) * 0.453592
        let dailyProteinRequirement = finalIntake * weightInKg
        DispatchQueue.main.async {
                self.dailyProteinIntake = dailyProteinRequirement // This will update the published property
                completion(dailyProteinRequirement)
            }
    }
    
    // Computed property for protein intake per meal
        var proteinIntakePerMeal: Double {
            let mealsPerDay = Double(userProfile?.mealsPerDay ?? 1)
            var intakePerMeal = dailyProteinIntake / mealsPerDay
            // Apply ceiling of 40g
            intakePerMeal = min(intakePerMeal, 40.0)
            return (intakePerMeal)
        }
    
    func predictActivityClass(steps: Double, runFrequency: Int, bikeFrequency: Int, hasActiveJob: Bool, gymFrequency: Int) -> Int {
        do {
            let model = try ActivityModel(configuration: MLModelConfiguration())
            
            // Create a MLMultiArray with shape [1, numFeatures]
            // This was not by choice, the model expected this kind of input automatically
            guard let multiArrayInput = try? MLMultiArray(shape: [1, 5], dataType: .float32) else {
                print("Failed to create MLMultiArray for model input.")
                return -1
            }
            
            // Assign the values to the multiArrayInput
            multiArrayInput[[0, 0]] = NSNumber(value: steps)
            multiArrayInput[[0, 1]] = NSNumber(value: runFrequency)
            multiArrayInput[[0, 2]] = NSNumber(value: bikeFrequency)
            multiArrayInput[[0, 3]] = NSNumber(value: hasActiveJob ? 1.0 : 0.0)
            multiArrayInput[[0, 4]] = NSNumber(value: gymFrequency)
            
            // Perform prediction using the reshaped input.
            let predictionOutput = try model.prediction(input: ActivityModelInput(dense_input: multiArrayInput))
 
            // Find the class label with the highest probability
            let predictedClass = predictionOutput.Identity.argmax()
            print("Predicted class from CoreML: \(String(describing: predictedClass))")
            return predictedClass!
        } catch {
            print("Error during CoreML prediction: \(error.localizedDescription)")
            return -1
        }
    }


    
    // Prepare data for the server
    func prepareDataForServer() -> [String: Any] {
        guard let profile = userProfile else { return [:] }
        let features: [String: Any] = [
            "avg_steps": averageSteps,
            "frequency_run": frequencyRun,
            "frequency_bike": frequencyBike,
            "active_job": profile.hasActiveJob ? 1 : 0,
            "gym_amount": profile.trainingFrequency
        ]
        // The server expects a dictionary with a key 'features' that contains another dictionary
        return ["features": features]
    }

    
    // Function to send data to server and use CoreML as fallback
    func sendDataToServer(completion: @escaping (Int) -> Void) {
        let serverURL = URL(string: "http://192.168.5.76:8888/predict")!
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let dataForServer = prepareDataForServer()

        guard let httpBody = try? JSONSerialization.data(withJSONObject: dataForServer, options: []) else {
            print("Error: Cannot create JSON")
            return
        }

        request.httpBody = httpBody

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error sending data to server: \(error), falling back to CoreML prediction.")
                // Server request failed, fallback to CoreML prediction
                let predictedClass = self.predictActivityClass(
                    steps: self.averageSteps,
                    runFrequency: self.frequencyRun,
                    bikeFrequency: self.frequencyBike,
                    hasActiveJob: self.userProfile?.hasActiveJob ?? false,
                    gymFrequency: self.userProfile?.trainingFrequency ?? 0
                )
                DispatchQueue.main.async {
                    completion(predictedClass)
                }
            } else if let data = data, let dataString = String(data: data, encoding: .utf8) {
                print("Response from server: \(dataString)")
                // Parse the response to get the predicted class
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                   let jsonDict = jsonObject as? [String: Any],
                   let predictedClasses = jsonDict["predicted_class"] as? [Int],
                   let predictedClass = predictedClasses.first {
                    DispatchQueue.main.async {
                        completion(predictedClass)
                    }
                } else {
                    print("Error: Could not parse the JSON response from the server")
                    // Server response parsing failed, fallback to CoreML prediction
                    let predictedClass = self.predictActivityClass(
                        steps: self.averageSteps,
                        runFrequency: self.frequencyRun,
                        bikeFrequency: self.frequencyBike,
                        hasActiveJob: self.userProfile?.hasActiveJob ?? false,
                        gymFrequency: self.userProfile?.trainingFrequency ?? 0
                    )
                    DispatchQueue.main.async {
                        completion(predictedClass)
                    }
                }
            }
        }
        task.resume()
    }
}

struct UserProfile {
    var heightFeet: Int
    var heightInches: Int
    var weight: Int
    var hasActiveJob: Bool
    var trainsAtGym: Bool
    var trainingFrequency: Int
    var sex: String
    var isPregnant: Bool
    var trainingGoal: String
    var mealsPerDay: Int

    init(from dictionary: [String: Any]) {
        heightFeet = dictionary["heightFeet"] as? Int ?? 0
        heightInches = dictionary["heightInches"] as? Int ?? 0
        weight = dictionary["weight"] as? Int ?? 0
        hasActiveJob = dictionary["hasActiveJob"] as? Bool ?? false
        trainsAtGym = dictionary["trainsAtGym"] as? Bool ?? false
        trainingFrequency = dictionary["trainingFrequency"] as? Int ?? 1
        sex = dictionary["sex"] as? String ?? ""
        isPregnant = dictionary["isPregnant"] as? Bool ?? false
        trainingGoal = dictionary["trainingGoal"] as? String ?? "Muscle gain"
        mealsPerDay = dictionary["mealsPerDay"] as? Int ?? 1
    }
}

// argmax is not a method for multi array, so I added a max function manually as an extension
extension MLMultiArray {
    func argmax() -> Int? {
        guard self.count > 0 else { return nil }
        var maxIndex = 0
        var maxValue = self[0].floatValue
        
        for i in 1..<self.count {
            let value = self[i].floatValue
            if value > maxValue {
                maxValue = value
                maxIndex = i
            }
        }
        return maxIndex
    }
}


