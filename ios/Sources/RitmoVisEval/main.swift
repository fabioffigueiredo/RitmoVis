import Darwin
import Foundation
import SquatCounterCore

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Uso: swift run ritmovis-eval caminho/para/anotacoes.json\n".utf8))
    exit(2)
}

do {
    let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let input = try JSONDecoder().decode(RepEvaluationInput.self, from: Data(contentsOf: inputURL))
    let result = try RepEvaluator.evaluate(input)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var output = try encoder.encode(result)
    output.append(0x0A)
    FileHandle.standardOutput.write(output)
} catch {
    FileHandle.standardError.write(Data("Falha na avaliação: \(error.localizedDescription)\n".utf8))
    exit(1)
}
