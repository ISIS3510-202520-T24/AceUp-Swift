import Foundation

// MARK: - Grade Calculator (Cálculo de notas con weights)
class GradeCalculator {
    
    static let shared = GradeCalculator()
    
    private init() {}
    
    // MARK: - Calcular nota actual basado en assignments completados
    func calculateCurrentGrade(entries: [GradeEntry]) -> GradeCalculationResult {
        let completedEntries = entries.filter { $0.earnedPoints != nil }
        
        guard !completedEntries.isEmpty else {
            return GradeCalculationResult(
                currentGrade: 0,
                weightedGrade: 0,
                completedWeight: 0,
                remainingWeight: 1.0,
                projectedGrade: nil
            )
        }
        
        var totalWeightedGrade: Double = 0
        var totalCompletedWeight: Double = 0
        
        for entry in completedEntries {
            if let contribution = entry.contributionToFinal {
                totalWeightedGrade += contribution
                totalCompletedWeight += entry.weight
            }
        }
        
        let currentGrade = totalCompletedWeight > 0 ? (totalWeightedGrade / totalCompletedWeight) * 5.0 : 0
        let remainingWeight = 1.0 - totalCompletedWeight
        
        return GradeCalculationResult(
            currentGrade: currentGrade,
            weightedGrade: totalWeightedGrade * 5.0,
            completedWeight: totalCompletedWeight,
            remainingWeight: remainingWeight,
            projectedGrade: nil
        )
    }
    
    // MARK: - Calcular qué nota necesita en lo que falta para alcanzar objetivo
    func calculateNeededGrade(currentResult: GradeCalculationResult, targetGrade: Double) -> Double {
        guard currentResult.remainingWeight > 0 else {
            return 0 // Ya completó todo
        }
        
        let neededWeightedPoints = (targetGrade / 5.0) - currentResult.weightedGrade / 5.0
        let neededGrade = (neededWeightedPoints / currentResult.remainingWeight) * 5.0
        
        return max(0, min(5.0, neededGrade))
    }
    
    // MARK: - Generar recomendaciones
    func getRecommendations(currentResult: GradeCalculationResult, targetGrade: Double) -> [String] {
        var recommendations: [String] = []
        
        let neededGrade = calculateNeededGrade(currentResult: currentResult, targetGrade: targetGrade)
        
        if currentResult.currentGrade >= targetGrade {
            recommendations.append("✅ ¡Vas bien! Ya alcanzaste tu objetivo de \(String(format: "%.1f", targetGrade))")
        } else if neededGrade > 5.0 {
            recommendations.append("⚠️ Es matemáticamente imposible alcanzar \(String(format: "%.1f", targetGrade))")
            recommendations.append("💡 Tu nota máxima posible es \(String(format: "%.1f", currentResult.weightedGrade + (currentResult.remainingWeight * 5.0)))")
        } else if neededGrade >= 4.5 {
            recommendations.append("🔥 Necesitas \(String(format: "%.1f", neededGrade)) en lo que falta - ¡Esfuerzo máximo!")
        } else if neededGrade >= 3.0 {
            recommendations.append("💪 Necesitas \(String(format: "%.1f", neededGrade)) en lo que falta - ¡Puedes lograrlo!")
        } else {
            recommendations.append("😌 Necesitas \(String(format: "%.1f", neededGrade)) en lo que falta - Vas muy bien")
        }
        
        if currentResult.completedWeight < 0.5 {
            recommendations.append("📊 Solo has completado \(Int(currentResult.completedWeight * 100))% del curso")
        }
        
        return recommendations
    }
}

// MARK: - Grade Calculation Result
struct GradeCalculationResult {
    let currentGrade: Double           // Nota actual (0-5.0)
    let weightedGrade: Double          // Suma ponderada
    let completedWeight: Double        // Peso completado (0-1.0)
    let remainingWeight: Double        // Peso restante (0-1.0)
    let projectedGrade: Double?        // Proyección si sigue igual
}
