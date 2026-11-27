import SwiftUI

// MARK: - Modelos de Datos
struct LogicData {
    struct TruthTableRow: Identifiable {
        let id = UUID()
        let inputs: [String: Bool]
        let output: Bool
        let minterm: Int?
        let maxterm: Int?
    }
    
    struct MinimizedExpression: Identifiable {
        let id = UUID()
        let method: String
        let expression: String
        let steps: [String]
        let theoremUsed: String?
    }
    
    struct KarnaughMap {
        let variables: [String]
        let grid: [[Bool]]
        let groups: [KarnaughGroup]
        
        struct KarnaughGroup {
            let cells: [CellPosition]
            let isPrimeImplicant: Bool
            let term: String
            
            struct CellPosition {
                let row: Int
                let column: Int
            }
        }
    }
    
    struct LogicGate: Identifiable, Equatable {
        let id = UUID()
        let type: GateType
        let inputs: [Int]
        var position: CGPoint
        let label: String?
        
        enum GateType: String, CaseIterable {
            case and, or, not, nand, nor, xor, xnor, input, output
        }
        
        static func == (lhs: LogicGate, rhs: LogicGate) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    struct Circuit {
        let gates: [LogicGate]
        let connections: [(from: Int, to: Int)]
    }
}

// MARK: - Formas de Compuertas
struct ANDShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 15, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 15, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// Antes esta forma trazaba el borde trasero abombado HACIA AFUERA (más hacia la izquierda en el
// medio que en las esquinas) y nunca llegaba a tocar el borde derecho real de su caja — el
// resultado era una especie de hoja/almendra pequeña y redondeada, muy distinta al símbolo
// clásico de OR (que tiene el borde trasero cóncavo, hundido hacia adentro, y una punta que sí
// llega hasta el borde derecho). Ahora el borde trasero se curva hacia ADENTRO (cóncavo, como en
// la compuerta AND real) y el cuerpo se abre hasta alcanzar la punta en el borde derecho, igual
// que en la imagen de referencia.
struct ORShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: rect.minX + rect.height * 0.35, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.minY))
        return path
    }
}

struct NOTShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 15, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        
        path.addEllipse(in: CGRect(x: rect.maxX - 20, y: rect.midY - 7, width: 14, height: 14))
        return path
    }
}

struct NANDShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = ANDShape().path(in: rect)
        path.addEllipse(in: CGRect(x: rect.maxX - 20, y: rect.midY - 7, width: 14, height: 14))
        return path
    }
}

struct NORShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = ORShape().path(in: rect)
        // La punta de la nueva forma de OR llega hasta "rect.maxX" (antes se quedaba corta), así
        // que la burbuja de negación se centra ahí mismo para quedar justo en la punta.
        path.addEllipse(in: CGRect(x: rect.maxX - 7, y: rect.midY - 7, width: 14, height: 14))
        return path
    }
}

struct XORShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = ORShape().path(in: rect)
        // Línea extra característica del XOR: repite la curva trasera cóncava de la OR, un poco
        // por detrás (a la izquierda) de ella.
        let extraBack: CGFloat = 8
        path.move(to: CGPoint(x: rect.minX - extraBack, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX - extraBack, y: rect.maxY),
            control: CGPoint(x: rect.minX - extraBack + rect.height * 0.35, y: rect.midY))
        return path
    }
}

struct XNORShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = XORShape().path(in: rect)
        path.addEllipse(in: CGRect(x: rect.maxX - 7, y: rect.midY - 7, width: 14, height: 14))
        return path
    }
}

// MARK: - Vista de Compuerta
struct GateShape: View {
    let type: LogicData.LogicGate.GateType
    let position: CGPoint
    let label: String?
    let isActive: Bool
    
    // Antes el contorno de cada compuerta solo se coloreaba (AND, OR, NOT...) cuando estaba
    // "encendida"; apagada, todas se veían del mismo gris/negro y costaba distinguir cuál era
    // cuál a simple vista. Ahora cada tipo siempre se dibuja con SU color identificador (el mismo
    // esquema que ya se usa en el simulador de "Relación": AND naranja, OR morado, NOT verde), y
    // el estado encendido/apagado se muestra aparte, con el relleno en verde — igual que pediste,
    // como en la imagen de referencia.
    private var fillColor: Color {
        switch type {
        case .input, .output:
            // Las entradas/salidas conservan su comportamiento de antes (relleno de su propio
            // color solo cuando están encendidas).
            return isActive ? identityColor.opacity(0.3) : Color.gray.opacity(0.1)
        default:
            return isActive ? Color.green.opacity(0.3) : Color.white
        }
    }

    private var strokeColor: Color {
        switch type {
        case .input, .output:
            // Las entradas/salidas son círculos con su propio punto indicador de 0/1 aparte;
            // conservan su comportamiento de antes (coloreado solo cuando están encendidas).
            return isActive ? identityColor : Color.black
        default:
            return identityColor
        }
    }

    private var identityColor: Color {
        switch type {
        case .input: return .green
        case .output: return .red
        case .and, .nand: return .orange
        case .or, .nor: return .purple
        case .not: return .green
        case .xor, .xnor: return .teal
        }
    }

    private var glowColor: Color {
        guard isActive else { return .clear }
        switch type {
        case .input, .output: return identityColor.opacity(0.5)
        default: return Color.green.opacity(0.5)
        }
    }
    
    @ViewBuilder
    private var gateView: some View {
        switch type {
        case .and:
            ANDShape()
                .fill(fillColor)
                .overlay(ANDShape().stroke(strokeColor, lineWidth: 2))
        case .or:
            ORShape()
                .fill(fillColor)
                .overlay(ORShape().stroke(strokeColor, lineWidth: 2))
        case .not:
            NOTShape()
                .fill(fillColor)
                .overlay(NOTShape().stroke(strokeColor, lineWidth: 2))
        case .nand:
            NANDShape()
                .fill(fillColor)
                .overlay(NANDShape().stroke(strokeColor, lineWidth: 2))
        case .nor:
            NORShape()
                .fill(fillColor)
                .overlay(NORShape().stroke(strokeColor, lineWidth: 2))
        case .xor:
            XORShape()
                .fill(fillColor)
                .overlay(XORShape().stroke(strokeColor, lineWidth: 2))
        case .xnor:
            XNORShape()
                .fill(fillColor)
                .overlay(XNORShape().stroke(strokeColor, lineWidth: 2))
        case .input, .output:
            Circle()
                .fill(fillColor)
                .overlay(Circle().stroke(strokeColor, lineWidth: 2))
        }
    }
    
    var body: some View {
        ZStack {
            gateView
                .frame(width: gateWidth, height: gateHeight)
                .shadow(color: glowColor, radius: 8)
            
            if type == .input || type == .output {
                Text(type == .input ? (label ?? "?") : "OUT")
                    .font(.system(size: type == .input ? 16 : 12, weight: .bold))
                    .foregroundColor(.black)
            }
            
            if type != .input && type != .output {
                Text(label ?? gateSymbol)
                    .font(.system(size: 12, weight: .bold))
                    .offset(y: gateHeight/2 + 15)
            }
            
            if type == .input {
                Circle()
                    .fill(isActive ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                    .offset(x: -25)
            } else if type == .output {
                Circle()
                    .fill(isActive ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                    .offset(x: 25)
            }
        }
        .position(position)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isActive ? Color.yellow : Color.clear, lineWidth: 2)
                .frame(width: gateWidth + 10, height: gateHeight + 10)
        )
    }
    
    private var gateWidth: CGFloat {
        switch type {
        case .input, .output: return 40
        case .not: return 45
        case .and, .or: return 60
        case .nand, .nor, .xor, .xnor: return 70
        }
    }
    
    private var gateHeight: CGFloat {
        switch type {
        case .input, .output: return 40
        default: return 50
        }
    }
    
    private var gateSymbol: String {
        switch type {
        case .and: return "AND"
        case .or: return "OR"
        case .not: return "NOT"
        case .nand: return "NAND"
        case .nor: return "NOR"
        case .xor: return "XOR"
        case .xnor: return "XNOR"
        default: return ""
        }
    }
}

// MARK: - Vista del Circuito
struct CircuitView: View {
    let circuit: LogicData.Circuit?
    @Binding var inputValues: [Bool]
    @Binding var outputValue: Bool
    
    private func isGateActive(_ gate: LogicData.LogicGate) -> Bool {
        guard let circuit = circuit else { return false }
        
        if gate.type == .input {
            let inputGates = circuit.gates.filter { $0.type == .input }
            if let inputIndex = inputGates.firstIndex(of: gate) {
                return inputIndex < inputValues.count ? inputValues[inputIndex] : false
            }
            return false
        } else if gate.type == .output {
            return outputValue
        }
        
        guard let gateIndex = circuit.gates.firstIndex(of: gate) else {
            return false
        }

        let inputConnections = circuit.connections.filter { $0.to == gateIndex }
        guard !inputConnections.isEmpty else { return false }

        // Antes esto siempre calculaba "todas las entradas activas" sin importar el tipo de
        // compuerta, así que una OR con una sola entrada en verdadero (que sí debería prender)
        // se mostraba apagada, y una NOT se mostraba prendida cuando su entrada era verdadera
        // (justo al revés). Ahora cada tipo de compuerta usa su propia función booleana, igual
        // que simulateCircuit(), para que lo que se ve encendido/apagado en el circuito
        // coincida siempre con el resultado real.
        let inputStates = inputConnections.map { isGateActive(circuit.gates[$0.from]) }

        switch gate.type {
        case .and:
            return inputStates.allSatisfy { $0 }
        case .or:
            return inputStates.contains(true)
        case .not:
            return inputStates.first.map { !$0 } ?? false
        case .nand:
            return !inputStates.allSatisfy { $0 }
        case .nor:
            return !inputStates.contains(true)
        case .xor:
            return inputStates.filter { $0 }.count % 2 == 1
        case .xnor:
            return inputStates.filter { $0 }.count % 2 == 0
        case .input, .output:
            return false // ya se resolvieron arriba
        }
    }
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if let circuit = circuit {
                // Antes el lienzo del circuito era un tamaño fijo (1200x800). Para expresiones
                // con pocas compuertas se veía bien, pero para expresiones más grandes (varios
                // términos con muchas variables, como cinco OR de AND-de-4-literales) las
                // compuertas de los últimos niveles quedaban posicionadas fuera de ese
                // rectángulo — y como el ScrollView solo puede desplazarse dentro del tamaño de
                // su contenido, esas compuertas nunca se llegaban a ver aunque sí existieran.
                // Ahora el lienzo crece según la posición real de la compuerta más a la derecha
                // y más abajo, así que el ScrollView siempre tiene espacio para mostrar el
                // circuito completo, sin importar cuántos niveles o compuertas tenga.
                let maxGateX = circuit.gates.map { $0.position.x }.max() ?? 0
                let maxGateY = circuit.gates.map { $0.position.y }.max() ?? 0
                let canvasWidth = max(1200, maxGateX + 150)
                let canvasHeight = max(800, maxGateY + 150)

                ZStack {
                    // Dibujar conexiones primero (detrás de las compuertas)
                    ForEach(0..<circuit.connections.count, id: \.self) { index in
                        let connection = circuit.connections[index]
                        let fromGate = circuit.gates[connection.from]
                        let toGate = circuit.gates[connection.to]
                        
                        let isActive = isGateActive(fromGate)
                        
                        Path { path in
                            let startPoint = connectionStartPoint(from: fromGate)
                            let endPoint = connectionEndPoint(to: toGate)
                            
                            path.move(to: startPoint)
                            path.addLine(to: CGPoint(x: startPoint.x + 30, y: startPoint.y))
                            
                            let midY = (startPoint.y + endPoint.y) / 2
                            path.addLine(to: CGPoint(x: startPoint.x + 30, y: midY))
                            
                            path.addLine(to: CGPoint(x: endPoint.x - 30, y: midY))
                            path.addLine(to: CGPoint(x: endPoint.x - 30, y: endPoint.y))
                            path.addLine(to: endPoint)
                        }
                        .stroke(isActive ? Color.green : Color.gray, lineWidth: 2)
                        .animation(.easeInOut, value: isActive)
                        
                        // Dibujar puntos de conexión
                        let startPoint = connectionStartPoint(from: fromGate)
                        let endPoint = connectionEndPoint(to: toGate)
                        let midY = (startPoint.y + endPoint.y) / 2
                        
                        Circle()
                            .fill(isActive ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                            .position(x: startPoint.x + 30, y: midY)
                        
                        Circle()
                            .fill(isActive ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                            .position(x: endPoint.x - 30, y: midY)
                    }
                    
                    // Dibujar compuertas encima de las conexiones
                    ForEach(circuit.gates) { gate in
                        GateShape(
                            type: gate.type,
                            position: gate.position,
                            label: gate.label,
                            isActive: isGateActive(gate)
                        )
                        .zIndex(1)
                    }
                }
                .frame(width: canvasWidth, height: canvasHeight)
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(radius: 5)
            } else {
                Text("No se pudo generar el circuito")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }
    
    private func connectionStartPoint(from gate: LogicData.LogicGate) -> CGPoint {
        switch gate.type {
        case .input: return CGPoint(x: gate.position.x + 20, y: gate.position.y)
        default: return CGPoint(x: gate.position.x + 35, y: gate.position.y)
        }
    }
    
    private func connectionEndPoint(to gate: LogicData.LogicGate) -> CGPoint {
        switch gate.type {
        case .output: return CGPoint(x: gate.position.x - 20, y: gate.position.y)
        default: return CGPoint(x: gate.position.x - 35, y: gate.position.y)
        }
    }
}

// MARK: - Analizador de Circuitos
class CircuitAnalyzer {
    let expression: String
    
    init(expression: String) {
        self.expression = expression
            .replacingOccurrences(of: "∧", with: "&")
            .replacingOccurrences(of: "∨", with: "|")
            .replacingOccurrences(of: "¬", with: "~")
            .replacingOccurrences(of: "⊕", with: "^")
            .replacingOccurrences(of: "⊼", with: "!&")
            .replacingOccurrences(of: "⊽", with: "!|")
    }
    
    func analyze() throws -> CircuitInfo {
        let tokens = try tokenize()
        let rpn = try shuntingYard(tokens: tokens)
        return try buildCircuit(from: rpn)
    }
    
    private func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        var currentToken = ""
        
        for char in expression {
            if char.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(createToken(from: currentToken))
                    currentToken = ""
                }
                continue
            }
            
            if isOp(char) || char == "(" || char == ")" || char == "⊼" || char == "⊽" {
                if !currentToken.isEmpty {
                    tokens.append(createToken(from: currentToken))
                    currentToken = ""
                }
                tokens.append(createToken(from: String(char)))
            } else {
                currentToken.append(char)
            }
        }
        
        if !currentToken.isEmpty {
            tokens.append(createToken(from: currentToken))
        }
        
        return tokens
    }
    
    private func createToken(from string: String) -> Token {
        if string == "&" || string == "∧" {
            return .op(.and)
        } else if string == "|" || string == "∨" {
            return .op(.or)
        } else if string == "~" || string == "¬" {
            return .op(.not)
        } else if string == "^" || string == "⊕" {
            return .op(.xor)
        } else if string == "!&" || string == "⊼" {
            return .op(.nand)
        } else if string == "!|" || string == "⊽" {
            return .op(.nor)
        } else if string == "(" {
            return .parenthesis(.open)
        } else if string == ")" {
            return .parenthesis(.close)
        } else {
            return .variable(string)
        }
    }
    
    private func isOp(_ char: Character) -> Bool {
        return char == "&" || char == "|" || char == "~" ||
               char == "∧" || char == "∨" || char == "¬" ||
               char == "^" || char == "⊕" || char == "⊼" || char == "⊽"
    }
    
    private func shuntingYard(tokens: [Token]) throws -> [Token] {
        var output: [Token] = []
        var operators: [Token] = []
        
        for token in tokens {
            switch token {
            case .variable:
                output.append(token)
            case .op(let op):
                // ¬ es unario y asocia a la derecha: si no distinguimos esto, "¬¬P" (o
                // cualquier cadena de negaciones sin paréntesis) queda mal armada porque el
                // ¬ ya en la pila se saca antes de que el segundo ¬ tenga operando, y la
                // evaluación termina reventando (pila vacía a mitad de la expresión). Para un
                // operador que asocia a la izquierda seguimos sacando mientras la precedencia
                // de arriba sea "mayor o igual"; para uno que asocia a la derecha (¬) solo
                // sacamos si es estrictamente mayor.
                let esAsociativoADerecha: Bool
                if case .not = op { esAsociativoADerecha = true } else { esAsociativoADerecha = false }
                while let lastOp = operators.last, case .op(let lastTokenOp) = lastOp,
                      esAsociativoADerecha
                        ? lastTokenOp.precedence > op.precedence
                        : lastTokenOp.precedence >= op.precedence {
                    output.append(operators.removeLast())
                }
                operators.append(token)
            case .parenthesis(.open):
                operators.append(token)
            case .parenthesis(.close):
                while let last = operators.last, last != .parenthesis(.open) {
                    output.append(operators.removeLast())
                }
                if operators.last == .parenthesis(.open) {
                    operators.removeLast()
                } else {
                    throw AnalysisError.mismatchedParentheses
                }
            }
        }
        
        while let last = operators.last {
            if case .parenthesis = last {
                throw AnalysisError.mismatchedParentheses
            }
            output.append(operators.removeLast())
        }
        
        return output
    }
    
    private func buildCircuit(from rpn: [Token]) throws -> CircuitInfo {
        var stack: [CircuitNode] = []
        var gates: [GateInfo] = []
        var nextGateId = 0
        
        for token in rpn {
            switch token {
            case .variable(let name):
                stack.append(.variable(name))
                
            case .op(let op):
                switch op {
                case .not:
                    guard let a = stack.popLast() else { throw AnalysisError.invalidExpression }
                    let gate = GateInfo(type: .not, inputs: [a], gateId: nextGateId)
                    gates.append(gate)
                    stack.append(.gate(nextGateId))
                    nextGateId += 1
                    
                case .and, .or, .xor, .nand, .nor:
                    guard let b = stack.popLast(), let a = stack.popLast() else {
                        throw AnalysisError.invalidExpression
                    }
                    let gateType: LogicData.LogicGate.GateType
                    switch op {
                    case .and: gateType = .and
                    case .or: gateType = .or
                    case .xor: gateType = .xor
                    case .nand: gateType = .nand
                    case .nor: gateType = .nor
                    default: gateType = .and
                    }
                    let gate = GateInfo(type: gateType, inputs: [a, b], gateId: nextGateId)
                    gates.append(gate)
                    stack.append(.gate(nextGateId))
                    nextGateId += 1
                }
                
            default:
                throw AnalysisError.invalidToken
            }
        }
        
        guard stack.count == 1 else {
            throw AnalysisError.invalidExpression
        }

        switch stack[0] {
        case .gate(let outputGateId):
            return CircuitInfo(gates: gates, outputGateId: outputGateId)
        case .variable(let name):
            // Una expresión que es solo una variable suelta (p. ej. "A") no genera ninguna
            // compuerta, así que antes esto tronaba con "Expresión inválida" y el circuito ni
            // siquiera se mostraba. La representamos con una OR de una sola entrada (A∨A≡A)
            // para poder dibujarla igual que cualquier otra expresión.
            let gate = GateInfo(type: .or, inputs: [.variable(name)], gateId: nextGateId)
            gates.append(gate)
            return CircuitInfo(gates: gates, outputGateId: nextGateId)
        }
    }
    
    enum Token: Equatable {
        case variable(String)
        case op(Operator)
        case parenthesis(Parenthesis)
        
        enum Operator {
            case and, or, not, xor, nand, nor
            
            var precedence: Int {
                switch self {
                case .not: return 4
                case .and, .nand: return 3
                case .or, .nor, .xor: return 2
                }
            }
        }
        
        enum Parenthesis {
            case open, close
        }
    }
    
    enum CircuitNode {
        case variable(String)
        case gate(Int)
    }
    
    struct GateInfo {
        let type: LogicData.LogicGate.GateType
        let inputs: [CircuitNode]
        let gateId: Int
    }
    
    struct CircuitInfo {
        let gates: [GateInfo]
        let outputGateId: Int
    }
    
    enum AnalysisError: Error, LocalizedError {
        case undefinedVariable(name: String)
        case mismatchedParentheses
        case invalidExpression
        case invalidToken
        
        var errorDescription: String? {
            switch self {
            case .undefinedVariable(let name):
                return "Variable no definida: \(name)"
            case .mismatchedParentheses:
                return "Paréntesis no coincidentes"
            case .invalidExpression:
                return "Expresión inválida"
            case .invalidToken:
                return "Token inválido en la expresión"
            }
        }
    }
}

// MARK: - Analizador de Expresiones Booleanas
class BooleanExpressionAnalyzer {
    let expression: String
    let variables: [String: Bool]
    
    init(expression: String, variables: [String: Bool]) {
        self.expression = expression
            .replacingOccurrences(of: "∧", with: "&")
            .replacingOccurrences(of: "∨", with: "|")
            .replacingOccurrences(of: "¬", with: "~")
            .replacingOccurrences(of: "⊕", with: "^")
            .replacingOccurrences(of: "⊼", with: "!&")
            .replacingOccurrences(of: "⊽", with: "!|")
        self.variables = variables
    }
    
    func evaluate() throws -> Bool {
        // Primero verifica si es una constante
        if expression == "1" { return true }
        if expression == "0" { return false }
        
        // Verifica variables individuales
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        if let value = variables[trimmed] {
            return value
        }
        
        // Si no es una variable simple, procede con el análisis
        let tokens = try tokenize()
        let rpn = try shuntingYard(tokens: tokens)
        return try evaluateRPN(tokens: rpn)
    }
    
    private func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        var currentToken = ""
        
        for char in expression {
            if char.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(createToken(from: currentToken))
                    currentToken = ""
                }
                continue
            }
            
            if isOp(char) || char == "(" || char == ")" || char == "⊼" || char == "⊽" {
                if !currentToken.isEmpty {
                    tokens.append(createToken(from: currentToken))
                    currentToken = ""
                }
                tokens.append(createToken(from: String(char)))
            } else {
                currentToken.append(char)
            }
        }
        
        if !currentToken.isEmpty {
            tokens.append(createToken(from: currentToken))
        }
        
        return tokens
    }
    
    private func createToken(from string: String) -> Token {
        if string == "&" || string == "∧" {
            return .op(.and)
        } else if string == "|" || string == "∨" {
            return .op(.or)
        } else if string == "~" || string == "¬" {
            return .op(.not)
        } else if string == "^" || string == "⊕" {
            return .op(.xor)
        } else if string == "!&" || string == "⊼" {
            return .op(.nand)
        } else if string == "!|" || string == "⊽" {
            return .op(.nor)
        } else if string == "(" {
            return .parenthesis(.open)
        } else if string == ")" {
            return .parenthesis(.close)
        } else {
            return .variable(string)
        }
    }
    
    private func isOp(_ char: Character) -> Bool {
        return char == "&" || char == "|" || char == "~" ||
               char == "∧" || char == "∨" || char == "¬" ||
               char == "^" || char == "⊕" || char == "⊼" || char == "⊽"
    }
    
    private func shuntingYard(tokens: [Token]) throws -> [Token] {
        var output: [Token] = []
        var operators: [Token] = []
        
        for token in tokens {
            switch token {
            case .variable:
                output.append(token)
            case .op(let op):
                // ¬ es unario y asocia a la derecha: si no distinguimos esto, "¬¬P" (o
                // cualquier cadena de negaciones sin paréntesis) queda mal armada porque el
                // ¬ ya en la pila se saca antes de que el segundo ¬ tenga operando, y la
                // evaluación termina reventando (pila vacía a mitad de la expresión). Para un
                // operador que asocia a la izquierda seguimos sacando mientras la precedencia
                // de arriba sea "mayor o igual"; para uno que asocia a la derecha (¬) solo
                // sacamos si es estrictamente mayor.
                let esAsociativoADerecha: Bool
                if case .not = op { esAsociativoADerecha = true } else { esAsociativoADerecha = false }
                while let lastOp = operators.last, case .op(let lastTokenOp) = lastOp,
                      esAsociativoADerecha
                        ? lastTokenOp.precedence > op.precedence
                        : lastTokenOp.precedence >= op.precedence {
                    output.append(operators.removeLast())
                }
                operators.append(token)
            case .parenthesis(.open):
                operators.append(token)
            case .parenthesis(.close):
                while let last = operators.last, last != .parenthesis(.open) {
                    output.append(operators.removeLast())
                }
                if operators.last == .parenthesis(.open) {
                    operators.removeLast()
                } else {
                    throw AnalysisError.mismatchedParentheses
                }
            }
        }
        
        while let last = operators.last {
            if case .parenthesis = last {
                throw AnalysisError.mismatchedParentheses
            }
            output.append(operators.removeLast())
        }
        
        return output
    }
    
    private func evaluateRPN(tokens: [Token]) throws -> Bool {
        var stack: [Bool] = []
        
        for token in tokens {
            switch token {
            case .variable(let name):
                guard let value = variables[name] else {
                    // Si la variable no está definida, asumir false
                    stack.append(false)
                    continue
                }
                stack.append(value)
            case .op(let op):
                switch op {
                case .not:
                    guard let a = stack.popLast() else { throw AnalysisError.invalidExpression }
                    stack.append(!a)
                case .and:
                    guard let b = stack.popLast(), let a = stack.popLast() else { throw AnalysisError.invalidExpression }
                    stack.append(a && b)
                case .or:
                    guard let b = stack.popLast(), let a = stack.popLast() else { throw AnalysisError.invalidExpression }
                    stack.append(a || b)
                case .xor:
                    guard let b = stack.popLast(), let a = stack.popLast() else { throw AnalysisError.invalidExpression }
                    stack.append(a != b)
                case .nand:
                    guard let b = stack.popLast(), let a = stack.popLast() else { throw AnalysisError.invalidExpression }
                    stack.append(!(a && b))
                case .nor:
                    guard let b = stack.popLast(), let a = stack.popLast() else { throw AnalysisError.invalidExpression }
                    stack.append(!(a || b))
                }
            default:
                throw AnalysisError.invalidToken
            }
        }
        
        guard stack.count == 1, let result = stack.first else {
            throw AnalysisError.invalidExpression
        }
        
        return result
    }
    
    enum Token: Equatable {
        case variable(String)
        case op(Operator)
        case parenthesis(Parenthesis)
        
        enum Operator {
            case and, or, not, xor, nand, nor
            
            var precedence: Int {
                switch self {
                case .not: return 4
                case .and, .nand: return 3
                case .or, .nor, .xor: return 2
                }
            }
        }
        
        enum Parenthesis {
            case open, close
        }
    }
    
    enum AnalysisError: Error, LocalizedError {
        case undefinedVariable(name: String)
        case mismatchedParentheses
        case invalidExpression
        case invalidToken
        
        var errorDescription: String? {
            switch self {
            case .undefinedVariable(let name):
                return "Variable no definida: \(name)"
            case .mismatchedParentheses:
                return "Paréntesis no coincidentes"
            case .invalidExpression:
                return "Expresión inválida"
            case .invalidToken:
                return "Token inválido en la expresión"
            }
        }
    }
}

// MARK: - Vista de Tabla de Verdad
struct TruthTableView: View {
    let rows: [LogicData.TruthTableRow]
    let minterms: [Int]
    let maxterms: [Int]
    let canonicalSOP: String
    let canonicalPOS: String
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 15) {
                if rows.isEmpty {
                    Text("Genera una tabla de verdad")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    truthTableSection
                    mintermsMaxtermsSection
                    canonicalFormsSection
                }
            }
            .padding()
        }
    }
    
    private var truthTableSection: some View {
        VStack(alignment: .leading) {
            Text("Tabla de Verdad")
                .font(.headline)
                .padding(.bottom, 5)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(rows[0].inputs.keys.sorted(), id: \.self) { name in
                            Text(name)
                                .frame(width: 50, height: 40)
                                .background(Color.blue)
                                .foregroundColor(.white)
                        }
                        Text("Salida")
                            .frame(width: 60, height: 40)
                            .background(Color.green)
                            .foregroundColor(.white)
                    }
                    
                    ForEach(rows.indices, id: \.self) { index in
                        let row = rows[index]
                        HStack(spacing: 0) {
                            ForEach(row.inputs.keys.sorted(), id: \.self) { name in
                                Text(row.inputs[name]! ? "1" : "0")
                                    .frame(width: 50, height: 40)
                                    .background(Color.gray.opacity(0.1))
                            }
                            Text(row.output ? "1" : "0")
                                .frame(width: 60, height: 40)
                                .background(Color.green.opacity(0.2))
                        }
                    }
                }
            }
        }
    }
    
    private var mintermsMaxtermsSection: some View {
        VStack(alignment: .leading) {
            Text("Minitérminos & Maxitérminos")
                .font(.headline)
                .padding(.bottom, 5)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Minitérminos (1):")
                        .foregroundColor(.orange)
                    Text(minterms.map { "m\($0)" }.joined(separator: ", "))
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Maxitérminos (0):")
                        .foregroundColor(.purple)
                    Text(maxterms.map { "M\($0)" }.joined(separator: ", "))
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)))
        }
    }
    
    private var canonicalFormsSection: some View {
        VStack(alignment: .leading) {
            Text("Formas Canónicas")
                .font(.headline)
                .padding(.bottom, 5)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Suma de Productos:")
                    .foregroundColor(.blue)
                Text(canonicalSOP)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                Text("Producto de Sumas:")
                    .foregroundColor(.green)
                Text(canonicalPOS)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Vista de Minimización
struct MinimizationView: View {
    let expressions: [LogicData.MinimizedExpression]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                if expressions.isEmpty {
                    Text("No hay resultados de minimización")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(expressions) { expr in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(expr.method)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                if let theorem = expr.theoremUsed {
                                    Spacer()
                                    Text(theorem)
                                        .font(.caption)
                                        .padding(5)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(5)
                                }
                            }
                            
                            Text(expr.expression)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            
                            if !expr.steps.isEmpty {
                                DisclosureGroup("Mostrar pasos") {
                                    VStack(alignment: .leading, spacing: 5) {
                                        ForEach(expr.steps, id: \.self) { step in
                                            Text("• \(step)")
                                                .padding(.vertical, 2)
                                        }
                                    }
                                    .padding(.top, 5)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Vista de Mapa de Karnaugh
struct KarnaughMapView: View {
    let map: LogicData.KarnaughMap?
    
    var body: some View {
        ScrollView {
            if let map = map {
                VStack(alignment: .center, spacing: 10) {
                    Text("Mapa de Karnaugh")
                        .font(.headline)
                    
                    if map.variables.count == 5 {
                        Text("Mapa de 5 variables (mostrando primera capa)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    // Encabezados de columnas
                    HStack(spacing: 0) {
                        Text("")
                            .frame(width: 50)
                        
                        if map.variables.count == 2 {
                            Text("0").frame(width: 50)
                            Text("1").frame(width: 50)
                        } else if map.variables.count == 3 {
                            Text("00").frame(width: 50)
                            Text("01").frame(width: 50)
                            Text("11").frame(width: 50)
                            Text("10").frame(width: 50)
                        } else if map.variables.count >= 4 {
                            Text("00").frame(width: 50)
                            Text("01").frame(width: 50)
                            Text("11").frame(width: 50)
                            Text("10").frame(width: 50)
                        }
                    }
                    
                    // Filas del mapa
                    ForEach(0..<map.grid.count, id: \.self) { row in
                        HStack(spacing: 0) {
                            // Etiqueta de fila
                            if map.variables.count == 2 {
                                Text(row == 0 ? "0" : "1").frame(width: 50)
                            } else if map.variables.count == 3 {
                                Text(row == 0 ? "0" : "1").frame(width: 50)
                            } else if map.variables.count >= 4 {
                                let labels = ["00", "01", "11", "10"]
                                Text(labels[row]).frame(width: 50)
                            }
                            
                            // Celdas del mapa
                            ForEach(0..<map.grid[row].count, id: \.self) { column in
                                ZStack {
                                    Text(map.grid[row][column] ? "1" : "0")
                                        .frame(width: 50, height: 50)
                                        .background(map.grid[row][column] ? Color.green.opacity(0.3) : Color.red.opacity(0.1))
                                        .border(Color.gray, width: 0.5)
                                    
                                    if let group = map.groups.first(where: { $0.cells.contains(where: { $0.row == row && $0.column == column }) }) {
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(group.isPrimeImplicant ? Color.blue : Color.orange, lineWidth: 2)
                                            .frame(width: 48, height: 48)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Leyenda de grupos
                    if !map.groups.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Grupos identificados:")
                                .font(.subheadline)
                                .padding(.top)
                            
                            ForEach(map.groups, id: \.term) { group in
                                HStack {
                                    Circle()
                                        .fill(group.isPrimeImplicant ? Color.blue : Color.orange)
                                        .frame(width: 10, height: 10)
                                    Text(group.term)
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Explicación de variables
                    if map.variables.count >= 3 {
                        VStack(alignment: .leading) {
                            Text("Codificación:")
                                .font(.subheadline)
                                .padding(.top)
                            
                            if map.variables.count == 3 {
                                Text("Filas: \(map.variables[0])")
                                Text("Columnas: \(map.variables[1]) y \(map.variables[2])")
                            } else if map.variables.count == 4 {
                                Text("Filas: \(map.variables[0]) y \(map.variables[1])")
                                Text("Columnas: \(map.variables[2]) y \(map.variables[3])")
                            } else if map.variables.count == 5 {
                                Text("Filas: \(map.variables[0]) y \(map.variables[1])")
                                Text("Columnas: \(map.variables[2]) y \(map.variables[3])")
                                Text("Capa: \(map.variables[4]) (0 = primera capa, 1 = segunda capa)")
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            } else {
                Text("El mapa de Karnaugh solo está disponible para 2 a 5 variables")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }
}

// MARK: - Minimizador de Quine-McCluskey
//
// Antes, tanto "Minimización" (método "Mapa de Karnaugh") como el mapa de Karnaugh visual
// armaban los grupos revisando a mano una sola posición fija de la cuadrícula por cada
// cantidad de variables, con el nombre de variable equivocado en varios casos. Para casi
// cualquier expresión de 3 a 5 variables (y para varios casos de 2) el resultado quedaba
// incompleto o de plano incorrecto. Esto implementa el algoritmo real de Quine-McCluskey:
// calcula todos los implicantes primos a partir de los minitérminos, elige los esenciales y
// completa la cobertura de forma voraz (agregando en cada paso el implicante que cubre más
// minitérminos pendientes). El resultado es una expresión mínima verdaderamente equivalente a
// la original, sin importar cuántas variables tenga o qué tan larga sea.
struct QMTerm {
    var bits: [Int?]        // nil = no importa (guion); si no, 0 o 1, indexado por variable
    var minterms: Set<Int>  // minitérminos originales que cubre este término
}

enum QuineMcCluskey {
    private static func key(for bits: [Int?]) -> String {
        bits.map { $0 == nil ? "-" : "\($0!)" }.joined()
    }

    private static func combine(_ a: QMTerm, _ b: QMTerm) -> QMTerm? {
        guard a.bits.count == b.bits.count else { return nil }
        var diffIndex: Int?
        for i in 0..<a.bits.count {
            if a.bits[i] != b.bits[i] {
                if a.bits[i] == nil || b.bits[i] == nil { return nil }
                if diffIndex != nil { return nil }
                diffIndex = i
            }
        }
        guard let idx = diffIndex else { return nil }
        var newBits = a.bits
        newBits[idx] = nil
        return QMTerm(bits: newBits, minterms: a.minterms.union(b.minterms))
    }

    /// Todos los implicantes primos de "minterms" (n variables): se combinan repetidamente
    /// pares de términos que difieren en un solo bit hasta que ya no se puede combinar más; lo
    /// que nunca se pudo combinar en cada ronda queda como implicante primo.
    static func primeImplicants(minterms: [Int], variableCount n: Int) -> [QMTerm] {
        guard !minterms.isEmpty else { return [] }

        var current: [String: QMTerm] = [:]
        for m in minterms {
            let bits: [Int?] = (0..<n).map { pos in (m >> (n - 1 - pos)) & 1 }
            let k = key(for: bits)
            if var existing = current[k] {
                existing.minterms.insert(m)
                current[k] = existing
            } else {
                current[k] = QMTerm(bits: bits, minterms: [m])
            }
        }

        var primes: [String: QMTerm] = [:]

        while true {
            var combinedKeys = Set<String>()
            var next: [String: QMTerm] = [:]
            let entries = Array(current.values)

            for i in 0..<entries.count {
                for j in (i + 1)..<entries.count {
                    guard let combined = combine(entries[i], entries[j]) else { continue }
                    combinedKeys.insert(key(for: entries[i].bits))
                    combinedKeys.insert(key(for: entries[j].bits))
                    let ck = key(for: combined.bits)
                    if var existing = next[ck] {
                        existing.minterms.formUnion(combined.minterms)
                        next[ck] = existing
                    } else {
                        next[ck] = combined
                    }
                }
            }

            for (k, term) in current where !combinedKeys.contains(k) {
                if var existing = primes[k] {
                    existing.minterms.formUnion(term.minterms)
                    primes[k] = existing
                } else {
                    primes[k] = term
                }
            }

            if next.isEmpty { break }
            current = next
        }

        return Array(primes.values)
    }

    /// Esenciales (cubren algún minitérmino que ningún otro implicante primo cubre) más una
    /// cobertura voraz del resto: en cada paso se agrega el implicante que cubre más
    /// minitérminos pendientes (y, en caso de empate, el que tiene menos literales).
    static func selectCover(
        primeImplicants: [QMTerm], minterms: [Int]
    ) -> (essential: [QMTerm], supplementary: [QMTerm]) {
        var coverage: [Int: [Int]] = [:]
        for (idx, term) in primeImplicants.enumerated() {
            for m in term.minterms where minterms.contains(m) {
                coverage[m, default: []].append(idx)
            }
        }

        var essentialIdx = Set<Int>()
        for m in minterms {
            if let idxs = coverage[m], idxs.count == 1 {
                essentialIdx.insert(idxs[0])
            }
        }

        var chosen = essentialIdx
        var covered = Set<Int>()
        for idx in chosen { covered.formUnion(primeImplicants[idx].minterms) }
        var remaining = Set(minterms).subtracting(covered)

        var supplementaryIdx = Set<Int>()
        while !remaining.isEmpty {
            var bestIdx: Int?
            var bestCoverCount = -1
            var bestLiteralCount = Int.max
            for (idx, term) in primeImplicants.enumerated() where !chosen.contains(idx) {
                let coverCount = term.minterms.intersection(remaining).count
                guard coverCount > 0 else { continue }
                let literalCount = term.bits.filter { $0 != nil }.count
                if coverCount > bestCoverCount || (coverCount == bestCoverCount && literalCount < bestLiteralCount) {
                    bestIdx = idx
                    bestCoverCount = coverCount
                    bestLiteralCount = literalCount
                }
            }
            guard let idx = bestIdx else { break } // no debería pasar: los PI cubren todos los minitérminos
            chosen.insert(idx)
            supplementaryIdx.insert(idx)
            remaining.subtract(primeImplicants[idx].minterms)
        }

        return (essentialIdx.map { primeImplicants[$0] }, supplementaryIdx.map { primeImplicants[$0] })
    }

    static func expression(for term: QMTerm, variableNames: [String]) -> String {
        let literals: [String] = term.bits.enumerated().compactMap { (i, bit) in
            guard let b = bit else { return nil }
            return b == 1 ? variableNames[i] : "¬\(variableNames[i])"
        }
        return literals.isEmpty ? "1" : literals.joined(separator: " ∧ ")
    }
}

// MARK: - Posiciones del Mapa de Karnaugh
//
// Antes la cuadrícula de 5 variables se armaba con índices de minitérmino escritos a mano que
// en realidad hacían que la "capa" correspondiera a la variable A (y no a E, como decía el
// texto de "Codificación" en pantalla) y que las filas/columnas mostraran B,C y D,E en vez de
// A,B y C,D. Esta fórmula general reemplaza esos índices sueltos: coincide exactamente con la
// distribución que ya se usaba (y que sí era correcta) para 2, 3 y 4 variables, y para 5
// variables sí hace que fila=A,B / columna=C,D / capa=E, como el texto ya le decía al usuario.

/// Orden de Gray para un valor de 2 bits: la posición p corresponde al valor binario
/// karnaughGrayOrder[p]. Esta permutación en particular es su propia inversa, así que la misma
/// tabla también sirve para ir de "valor binario" a "posición".
let karnaughGrayOrder = [0, 1, 3, 2]

func karnaughBit(_ minterm: Int, _ variableCount: Int, _ position: Int) -> Int {
    (minterm >> (variableCount - 1 - position)) & 1
}

/// En qué (fila, columna, capa) del mapa de Karnaugh cae un minitérmino dado.
func karnaughPosition(forMinterm minterm: Int, variableCount n: Int) -> (row: Int, column: Int, layer: Int) {
    switch n {
    case 2:
        return (karnaughBit(minterm, n, 0), karnaughBit(minterm, n, 1), 0)
    case 3:
        let bc = (karnaughBit(minterm, n, 1) << 1) | karnaughBit(minterm, n, 2)
        return (karnaughBit(minterm, n, 0), karnaughGrayOrder[bc], 0)
    default: // 4 o 5
        let ab = (karnaughBit(minterm, n, 0) << 1) | karnaughBit(minterm, n, 1)
        let cd = (karnaughBit(minterm, n, 2) << 1) | karnaughBit(minterm, n, 3)
        let layer = n == 5 ? karnaughBit(minterm, n, 4) : 0
        return (karnaughGrayOrder[ab], karnaughGrayOrder[cd], layer)
    }
}

// MARK: - Vista Principal
struct BooleanLogicView: View {
    @State private var expression = "A⊼B"  // Ejemplo inicial con NAND
    @State private var variables: [String: Bool] = [:]
    @State private var truthTable: [LogicData.TruthTableRow] = []
    @State private var minimizedExpressions: [LogicData.MinimizedExpression] = []
    @State private var karnaughMap: LogicData.KarnaughMap?
    @State private var circuit: LogicData.Circuit?
    @State private var selectedTab = 0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCircuitSimulator = false
    @State private var showSymbolPalette = false
    @State private var minterms: [Int] = []
    @State private var maxterms: [Int] = []
    @State private var canonicalSOP = ""
    @State private var canonicalPOS = ""
    @State private var inputValues: [Bool] = []
    @State private var outputValue = false
    
    private let tabs = ["Tabla de Verdad", "Minimización", "Karnaugh", "Circuito"]
    private let maxVariables = 5
    // Antes incluía "[", "]", "{" y "}", pero el analizador de esta pantalla (tokenize/isOp)
    // solo reconoce "(" y ")" como paréntesis — esos otros símbolos ni siquiera se separaban
    // como su propio token, así que tocarlos metía un carácter suelto en la expresión que
    // rompía la evaluación (error de "Expresión inválida"). Se quitan para que todo botón del
    // teclado corresponda a algo que la expresión realmente sabe interpretar.
    private let paletteSymbols = ["A", "B", "C", "D", "E", "∧", "∨", "¬", "⊕", "⊼", "⊽", "(", ")"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                expressionInputView

                if showSymbolPalette {
                    symbolKeyboard
                }

                variablesPanel
                tabSelector
                tabContent
            }
            .navigationTitle("Lógica Booleana")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showCircuitSimulator.toggle() }) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 18))
                        }
                        
                        Button(action: { showSymbolPalette.toggle() }) {
                            Image(systemName: "function")
                                .font(.system(size: 18))
                        }
                    }
                }
            }
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showCircuitSimulator) {
                circuitSimulator
            }
            .onAppear(perform: analizar)
            .onChange(of: expression) { _ in analizar() }
            .animation(.easeInOut, value: showSymbolPalette)
        }
    }
    
    // MARK: - Componentes de UI
    private var expressionInputView: some View {
        HStack(spacing: 10) {
            Button(action: clearAll) {
                Image(systemName: "trash")
                    .padding(8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            TextField("Ej: A⊼B", text: $expression)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body, design: .monospaced))
                .keyboardType(.asciiCapable)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding(.horizontal)
    }
    
    // Antes cada variable tenía su propio switch on/off, pero ese valor no se usaba en ningún
    // lado: la tabla de verdad, el mapa de Karnaugh y la minimización siempre prueban TODAS las
    // combinaciones posibles por su cuenta, así que mover esos switches no cambiaba nada en
    // pantalla. Se quitan para no confundir, y se deja solo el nombre de cada variable. También
    // se agrega un botón "-" (simétrico al "+") para poder quitar la última variable agregada.
    private var variablesPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(variables.keys.sorted(), id: \.self) { variable in
                    Text(variable)
                        .font(.headline)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }

                if !variables.isEmpty {
                    Button(action: removeVariable) {
                        // El símbolo "minus" es más ancho que alto (a diferencia de "plus", que
                        // es cuadrado), así que sin un tamaño fijo el botón salía más ancho que
                        // el de agregar. Se fija el mismo tamaño en los dos.
                        Image(systemName: "minus")
                            .frame(width: 16, height: 16)
                            .padding(8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }

                if variables.count < maxVariables {
                    Button(action: addVariable) {
                        Image(systemName: "plus")
                            .frame(width: 16, height: 16)
                            .padding(8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var tabSelector: some View {
        Picker("", selection: $selectedTab) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Text(tabs[index]).tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case 0:
                TruthTableView(rows: truthTable, minterms: minterms, maxterms: maxterms, canonicalSOP: canonicalSOP, canonicalPOS: canonicalPOS)
            case 1:
                MinimizationView(expressions: minimizedExpressions)
            case 2:
                KarnaughMapView(map: karnaughMap)
            case 3:
                CircuitView(circuit: circuit, inputValues: $inputValues, outputValue: $outputValue)
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var symbolKeyboard: some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
        return LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(paletteSymbols, id: \.self) { symbol in
                Button(action: {
                    expression += symbol
                }) {
                    Text(symbol)
                        .font(.title)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var circuitSimulator: some View {
        VStack {
            if circuit != nil {
                CircuitView(circuit: circuit, inputValues: $inputValues, outputValue: $outputValue)
                    .padding()
                
                inputControls
                outputDisplay
            }
        }
        .navigationTitle("Simulador de Circuito")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cerrar") { showCircuitSimulator = false }
            }
        }
        .onAppear {
            setupInputs()
        }
    }
    
    private var inputControls: some View {
        VStack {
            if let circuit = circuit {
                ForEach(0..<inputValues.count, id: \.self) { index in
                    HStack {
                        Text("Entrada \(index + 1):")
                        Toggle(isOn: $inputValues[index]) {
                            Text(inputValues[index] ? "1" : "0")
                        }
                        .onChange(of: inputValues[index]) { _ in
                            simulateCircuit()
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var outputDisplay: some View {
        HStack {
            Text("Salida:")
                .font(.headline)
            Text(outputValue ? "1" : "0")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(outputValue ? .green : .red)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
    }
    
    // MARK: - Lógica de Negocio
    private func extractVariables() {
        let pattern = "[A-Za-z]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        
        let matches = regex.matches(
            in: expression,
            range: NSRange(expression.startIndex..., in: expression))
        
        var newVariables: [String: Bool] = [:]
        for match in matches {
            if let range = Range(match.range, in: expression) {
                let variable = String(expression[range]).uppercased()
                newVariables[variable] = variables[variable] ?? false
            }
        }
        
        variables = newVariables
    }
    
    /// Une extractVariables() + evaluate(). Se llama automáticamente cada vez que cambia la
    /// expresión (.onChange) y al abrir la pantalla (.onAppear), para que la tabla de verdad,
    /// minimización, Karnaugh y circuito se actualicen solos mientras se escribe, sin depender
    /// de ningún botón.
    private func analizar() {
        extractVariables()
        evaluate()
    }

    private func clearAll() {
        expression = ""
        variables = [:]
        truthTable = []
        minimizedExpressions = []
        karnaughMap = nil
        circuit = nil
        minterms = []
        maxterms = []
        canonicalSOP = ""
        canonicalPOS = ""
        inputValues = []
        outputValue = false
        showError = false
    }
    
    private func addVariable() {
        guard variables.count < maxVariables else { return }

        // Encuentra la próxima letra disponible
        let existingLetters = Set(variables.keys)
        for ascii in 65..<(65+26) { // A-Z
            let letter = String(UnicodeScalar(ascii)!)
            if !existingLetters.contains(letter) {
                variables[letter] = false
                evaluate()
                return
            }
        }
    }

    /// Quita la última variable (la letra más alta) — simétrico al botón "+". Si esa letra
    /// todavía aparece escrita en la expresión, "extractVariables()" la va a volver a agregar en
    /// cuanto el usuario vuelva a tocar el campo de texto, igual que ya pasa con "+".
    private func removeVariable() {
        guard let lastLetter = variables.keys.sorted().last else { return }
        variables.removeValue(forKey: lastLetter)
        evaluate()
    }
    
    private func evaluate() {
        // Antes, borrar la expresión (o quedarse sin ninguna variable, p. ej. justo después de
        // presionar el botón de la papelera) hacía que generateTruthTable() reventara con "Se
        // requiere al menos una variable" y esa alerta se le mostraba al usuario como si fuera
        // un error de verdad — aunque simplemente no hay nada que evaluar todavía. Ahora, en
        // ese caso, se limpian los resultados en silencio y no se muestra ninguna alerta;
        // los demás errores (paréntesis mal balanceados, token inválido, etc.) sí se siguen
        // mostrando, porque esos sí indican una expresión mal escrita.
        guard !expression.trimmingCharacters(in: .whitespaces).isEmpty, !variables.isEmpty else {
            truthTable = []
            minimizedExpressions = []
            karnaughMap = nil
            circuit = nil
            minterms = []
            maxterms = []
            canonicalSOP = ""
            canonicalPOS = ""
            showError = false
            return
        }

        do {
            try generateTruthTable()
            try findMintermsMaxterms()
            try generateCanonicalForms()
            try minimizeExpressions()
            try generateKarnaughMap()
            try generateCircuit()
            showError = false
        } catch {
            // No mostramos errores para variables no definidas
            if !error.localizedDescription.contains("undefined") {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func generateTruthTable() throws {
        let variableNames = variables.keys.sorted()
        guard !variableNames.isEmpty else {
            throw NSError(domain: "No hay variables", code: 0, userInfo: [NSLocalizedDescriptionKey: "Se requiere al menos una variable"])
        }
        
        var table: [LogicData.TruthTableRow] = []
        let rowCount = Int(pow(2, Double(variableNames.count)))
        
        for i in 0..<rowCount {
            var inputs: [String: Bool] = [:]
            for (index, name) in variableNames.enumerated() {
                let bitPosition = variableNames.count - 1 - index
                inputs[name] = (i >> bitPosition) & 1 == 1
            }
            
            let analyzer = BooleanExpressionAnalyzer(expression: expression, variables: inputs)
            let output = try analyzer.evaluate()
            let minterm = output ? i : nil
            let maxterm = output ? nil : i
            table.append(LogicData.TruthTableRow(inputs: inputs, output: output, minterm: minterm, maxterm: maxterm))
        }
        
        truthTable = table
    }
    
    private func findMintermsMaxterms() throws {
        minterms = truthTable.indices.filter { truthTable[$0].output }
        maxterms = truthTable.indices.filter { !truthTable[$0].output }
    }
    
    private func generateCanonicalForms() throws {
        let variableNames = variables.keys.sorted()
        
        // Suma de Productos (minterms)
        var sopTerms: [String] = []
        for minterm in minterms {
            var term: [String] = []
            for (i, varName) in variableNames.enumerated() {
                let bitPosition = variableNames.count - 1 - i
                let isPositive = (minterm >> bitPosition) & 1 == 1
                term.append(isPositive ? varName : "¬\(varName)")
            }
            sopTerms.append(term.joined(separator: " ∧ "))
        }
        canonicalSOP = sopTerms.joined(separator: " ∨ ")
        
        // Producto de Sumas (maxterms)
        var posTerms: [String] = []
        for maxterm in maxterms {
            var term: [String] = []
            for (i, varName) in variableNames.enumerated() {
                let bitPosition = variableNames.count - 1 - i
                let isPositive = (maxterm >> bitPosition) & 1 == 1
                term.append(isPositive ? "¬\(varName)" : varName)
            }
            posTerms.append("(\(term.joined(separator: " ∨ ")))")
        }
        canonicalPOS = posTerms.joined(separator: " ∧ ")
    }
    
    private func minimizeExpressions() throws {
        var results: [LogicData.MinimizedExpression] = []
        let variableNames = variables.keys.sorted()
        
        // Formas canónicas
        results.append(LogicData.MinimizedExpression(
            method: "Suma de Productos (Canónica)",
            expression: canonicalSOP,
            steps: ["Minitérminos: \(minterms.map { String($0) }.joined(separator: ", "))"],
            theoremUsed: nil
        ))
        
        results.append(LogicData.MinimizedExpression(
            method: "Producto de Sumas (Canónica)",
            expression: canonicalPOS,
            steps: ["Maxitérminos: \(maxterms.map { String($0) }.joined(separator: ", "))"],
            theoremUsed: nil
        ))
        
        // Minimización básica basada en teoremas
        if expression.contains("∧") && expression.contains("∨") {
            // Teorema de absorción: A ∨ (A ∧ B) = A
            if let absorbed = applyAbsorptionTheorem(expression: expression) {
                results.append(LogicData.MinimizedExpression(
                    method: "Teorema de Absorción",
                    expression: absorbed,
                    steps: ["A ∨ (A ∧ B) = A"],
                    theoremUsed: "Absorción"
                ))
            }
            
            // Teorema de De Morgan
            if let demorgan = applyDeMorganTheorem(expression: expression) {
                results.append(LogicData.MinimizedExpression(
                    method: "Teorema de De Morgan",
                    expression: demorgan,
                    steps: ["¬(A ∧ B) = ¬A ∨ ¬B", "¬(A ∨ B) = ¬A ∧ ¬B"],
                    theoremUsed: "De Morgan"
                ))
            }
        }
        
        // Minimización con mapa de Karnaugh (si es posible)
        if variableNames.count <= 5 {
            if let minimizedKarnaugh = try minimizeWithKarnaugh() {
                results.append(minimizedKarnaugh)
            }
        }
        
        minimizedExpressions = results
    }
    
    private func applyAbsorptionTheorem(expression: String) -> String? {
        let patterns = [
            "([A-Z])\\s*∨\\s*\\(\\1\\s*∧\\s*([A-Z])\\)": "$1",
            "\\(([A-Z])\\s*∧\\s*([A-Z])\\)\\s*∨\\s*\\1": "$1"
        ]

        var result = expression
        var changed = false

        for (pattern, template) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: result.utf16.count)
                let newResult = regex.stringByReplacingMatches(in: result, range: range, withTemplate: template)
                if newResult != result {
                    changed = true
                    result = newResult
                }
            }
        }

        return changed ? result : nil
    }

    private func applyDeMorganTheorem(expression: String) -> String? {
        // Antes esto marcaba "changed = true" apenas el patrón compilaba, sin importar si en
        // realidad encontró y reemplazó algo — así que la tarjeta "Teorema de De Morgan"
        // aparecía SIEMPRE que la expresión tuviera ∧ y ∨ (mostrando la expresión sin ningún
        // cambio real, como si fuera una simplificación válida). También exigía exactamente un
        // espacio alrededor de ∧/∨, pero el teclado de esta pantalla escribe "¬(A∧B)" sin
        // espacios. Ahora acepta espacios opcionales y solo se considera "cambiada" si el
        // resultado es distinto del original.
        var result = expression

        // ¬(A ∧ B) → ¬A ∨ ¬B
        let pattern1 = "¬\\(([A-Z])\\s*∧\\s*([A-Z])\\)"
        if let regex1 = try? NSRegularExpression(pattern: pattern1) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex1.stringByReplacingMatches(in: result, range: range, withTemplate: "¬$1 ∨ ¬$2")
        }

        // ¬(A ∨ B) → ¬A ∧ ¬B
        let pattern2 = "¬\\(([A-Z])\\s*∨\\s*([A-Z])\\)"
        if let regex2 = try? NSRegularExpression(pattern: pattern2) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex2.stringByReplacingMatches(in: result, range: range, withTemplate: "¬$1 ∧ ¬$2")
        }

        return result != expression ? result : nil
    }

    // Antes esta función solo reconocía UN caso particular de agrupación por cada cantidad de
    // variables (por ejemplo, para 3 y 4 variables solo miraba una esquina fija del mapa,
    // ignorando el resto), y hasta ese único caso tenía el nombre de variable equivocado (p.
    // ej. para 2 variables intercambiaba qué literal correspondía a filas y cuál a columnas).
    // El resultado casi nunca coincidía con la expresión real salvo por casualidad. Ahora se
    // calculan los implicantes primos de verdad (Quine-McCluskey) a partir de los
    // minitérminos, lo mismo que ya usa el mapa de Karnaugh visual, así que el resultado es
    // siempre una expresión mínima equivalente a la original sin importar cuántas variables o
    // qué tan larga sea.
    private func minimizeWithKarnaugh() throws -> LogicData.MinimizedExpression? {
        let variableNames = variables.keys.sorted()
        let n = variableNames.count
        guard n >= 1 else { return nil }

        if minterms.isEmpty {
            return LogicData.MinimizedExpression(
                method: "Mapa de Karnaugh",
                expression: "0",
                steps: ["No hay minitérminos: la expresión es siempre falsa"],
                theoremUsed: "Karnaugh"
            )
        }

        if minterms.count == (1 << n) {
            return LogicData.MinimizedExpression(
                method: "Mapa de Karnaugh",
                expression: "1",
                steps: ["Todos los minitérminos están presentes: la expresión es siempre verdadera"],
                theoremUsed: "Karnaugh"
            )
        }

        let primes = QuineMcCluskey.primeImplicants(minterms: minterms, variableCount: n)
        let (essential, supplementary) = QuineMcCluskey.selectCover(primeImplicants: primes, minterms: minterms)
        guard !essential.isEmpty || !supplementary.isEmpty else { return nil }

        let essentialTerms = essential.map { QuineMcCluskey.expression(for: $0, variableNames: variableNames) }
        let supplementaryTerms = supplementary.map { QuineMcCluskey.expression(for: $0, variableNames: variableNames) }

        var steps = ["Implicantes primos esenciales: \(essentialTerms.joined(separator: ", "))"]
        if !supplementaryTerms.isEmpty {
            steps.append("Implicantes adicionales para cubrir el resto: \(supplementaryTerms.joined(separator: ", "))")
        }

        return LogicData.MinimizedExpression(
            method: "Mapa de Karnaugh",
            expression: (essentialTerms + supplementaryTerms).joined(separator: " ∨ "),
            steps: steps,
            theoremUsed: "Karnaugh"
        )
    }
    
    // Antes, la cuadrícula de 5 variables se armaba con índices de minitérmino escritos "a
    // mano" que en realidad hacían que la "capa" correspondiera a la primera variable (A) y no
    // a la última (E) como decía el texto de "Codificación" debajo del mapa — es decir, los
    // valores mostrados no correspondían con lo que la pantalla decía que representaban. Y en
    // todos los casos (2 a 5 variables), los "grupos" resaltados en el mapa solo revisaban UNA
    // posición fija de la cuadrícula (por ejemplo, nada más la esquina superior izquierda), así
    // que para la enorme mayoría de expresiones no se marcaba ningún grupo, o se marcaba con el
    // nombre de variable equivocado. Ahora la cuadrícula se arma con una sola fórmula general
    // (verificada para que reproduzca exactamente la misma distribución que ya se usaba para 2,
    // 3 y 4 variables) y los grupos salen de los implicantes primos reales (Quine-McCluskey),
    // así que cubren TODA expresión, no solo un caso particular.
    private func generateKarnaughMap() throws {
        let variableNames = variables.keys.sorted()
        let n = variableNames.count
        guard n >= 2 && n <= 5 else {
            karnaughMap = nil
            return
        }

        // Para 3 variables solo hay UNA variable de fila (A: 0 o 1), así que son 2 filas, no 4 —
        // con rowCount=4 el bucle de abajo llamaba minterm(forRow: 2, ...) y minterm(forRow: 3,
        // ...), que para n=3 caen fuera de rango (8-11 en vez de 0-7) y hacían que
        // truthTable[...] reventara con un índice fuera de límites apenas se probaba una
        // expresión de 3 variables como (A∧B)∨(A∧C)∨(B∧C).
        let rowCount = (n == 2 || n == 3) ? 2 : 4
        let colCount = (n == 2) ? 2 : 4

        func minterm(forRow row: Int, column: Int) -> Int {
            switch n {
            case 2:
                return (row << 1) | column
            case 3:
                let bc = karnaughGrayOrder[column]
                return (row << 2) | bc
            default: // 4 o 5
                let ab = karnaughGrayOrder[row]
                let cd = karnaughGrayOrder[column]
                return n == 5 ? (ab << 3) | (cd << 1) : (ab << 2) | cd
            }
        }

        var grid: [[Bool]] = []
        for row in 0..<rowCount {
            var rowValues: [Bool] = []
            for column in 0..<colCount {
                // Para 5 variables esto arma la "capa 0" (E = 0), que es la que se muestra.
                rowValues.append(truthTable[minterm(forRow: row, column: column)].output)
            }
            grid.append(rowValues)
        }

        var groups: [LogicData.KarnaughMap.KarnaughGroup] = []

        if !minterms.isEmpty && minterms.count < (1 << n) {
            let primes = QuineMcCluskey.primeImplicants(minterms: minterms, variableCount: n)
            let (essential, supplementary) = QuineMcCluskey.selectCover(primeImplicants: primes, minterms: minterms)

            func cells(for term: QMTerm) -> [LogicData.KarnaughMap.KarnaughGroup.CellPosition] {
                var result: [LogicData.KarnaughMap.KarnaughGroup.CellPosition] = []
                for m in 0..<(1 << n) {
                    var matches = true
                    for i in 0..<n {
                        if let fixedBit = term.bits[i], karnaughBit(m, n, i) != fixedBit {
                            matches = false
                            break
                        }
                    }
                    guard matches else { continue }
                    let position = karnaughPosition(forMinterm: m, variableCount: n)
                    // Para 5 variables solo dibujamos el contorno sobre la capa mostrada (E=0);
                    // el grupo sigue siendo correcto aunque también cubra celdas de la capa 2.
                    if position.layer == 0 {
                        result.append(.init(row: position.row, column: position.column))
                    }
                }
                return result
            }

            for term in essential {
                groups.append(LogicData.KarnaughMap.KarnaughGroup(
                    cells: cells(for: term),
                    isPrimeImplicant: true,
                    term: QuineMcCluskey.expression(for: term, variableNames: variableNames)
                ))
            }
            for term in supplementary {
                groups.append(LogicData.KarnaughMap.KarnaughGroup(
                    cells: cells(for: term),
                    isPrimeImplicant: false,
                    term: QuineMcCluskey.expression(for: term, variableNames: variableNames)
                ))
            }
        } else if minterms.count == (1 << n) {
            // Tautología: todo el mapa (mostrado) es 1.
            var allCells: [LogicData.KarnaughMap.KarnaughGroup.CellPosition] = []
            for row in 0..<rowCount {
                for column in 0..<colCount {
                    allCells.append(.init(row: row, column: column))
                }
            }
            groups.append(LogicData.KarnaughMap.KarnaughGroup(cells: allCells, isPrimeImplicant: true, term: "1"))
        }

        karnaughMap = LogicData.KarnaughMap(variables: variableNames, grid: grid, groups: groups)
    }
    
    private func generateCircuit() throws {
        let variableNames = variables.keys.sorted()
        var gates: [LogicData.LogicGate] = []
        var connections: [(from: Int, to: Int)] = []
        
        // Constantes para el diseño
        let inputSpacing: CGFloat = 80
        let verticalSpacing: CGFloat = 100
        let horizontalSpacing: CGFloat = 150
        let startX: CGFloat = 100
        let startY: CGFloat = 150
        
        // Crear compuertas de entrada en línea vertical a la izquierda
        for (index, name) in variableNames.enumerated() {
            gates.append(LogicData.LogicGate(
                type: .input,
                inputs: [],
                position: CGPoint(x: startX, y: startY + CGFloat(index) * inputSpacing),
                label: name
            ))
        }
        
        // Analizar expresión para crear circuito
        let analyzer = CircuitAnalyzer(expression: expression)
        let circuitInfo = try analyzer.analyze()
        
        // Organizar compuertas en niveles (columnas) basado en dependencias
        var gateLevels: [[Int]] = []
        var placedGates: Set<Int> = []
        var gateIdToIndex: [Int: Int] = [:]
        
        // Asignar cada compuerta a un nivel basado en sus dependencias
        for gateInfo in circuitInfo.gates {
            let gateIndex = gates.count
            gateIdToIndex[gateInfo.gateId] = gateIndex
            
            let gateType: LogicData.LogicGate.GateType = {
                switch gateInfo.type {
                case .and: return .and
                case .or: return .or
                case .not: return .not
                case .xor: return .xor
                case .nand: return .nand
                case .nor: return .nor
                default: return .and
                }
            }()
            
            gates.append(LogicData.LogicGate(
                type: gateType,
                inputs: [],
                position: CGPoint.zero, // La posición se establecerá más tarde
                label: nil
            ))
        }
        
        // Función para determinar nivel de compuerta
        func levelForGate(_ gateId: Int) -> Int {
            var maxLevel = 0
            let gateInfo = circuitInfo.gates.first(where: { $0.gateId == gateId })!
            
            for input in gateInfo.inputs {
                switch input {
                case .variable(_):
                    break // Las variables de entrada son nivel 0
                case .gate(let inputGateId):
                    maxLevel = max(maxLevel, levelForGate(inputGateId) + 1)
                }
            }
            return maxLevel
        }
        
        // Asignar niveles a todas las compuertas
        var maxLevel = 0
        for gateInfo in circuitInfo.gates {
            let level = levelForGate(gateInfo.gateId)
            maxLevel = max(maxLevel, level)
            
            while gateLevels.count <= level {
                gateLevels.append([])
            }
            gateLevels[level].append(gateInfo.gateId)
        }
        
        // Posicionar compuertas en columnas basado en sus niveles
        for (level, gateIds) in gateLevels.enumerated() {
            let x = startX + CGFloat(level + 1) * horizontalSpacing
            
            // Distribuir compuertas verticalmente en este nivel
            for (index, gateId) in gateIds.enumerated() {
                let y = startY + CGFloat(index) * verticalSpacing
                if let gateIndex = gateIdToIndex[gateId] {
                    gates[gateIndex].position = CGPoint(x: x, y: y)
                }
            }
        }
        
        // Crear conexiones
        for (i, gateInfo) in circuitInfo.gates.enumerated() {
            let gateIndex = gateIdToIndex[gateInfo.gateId]!
            
            for input in gateInfo.inputs {
                switch input {
                case .variable(let name):
                    if let inputIndex = variableNames.firstIndex(of: name) {
                        connections.append((from: inputIndex, to: gateIndex))
                    }
                case .gate(let inputGateId):
                    if let inputIndex = gateIdToIndex[inputGateId] {
                        connections.append((from: inputIndex, to: gateIndex))
                    }
                }
            }
        }
        
        // Posicionar compuerta de salida a la derecha del último nivel
        if let outputGateIndex = gateIdToIndex[circuitInfo.outputGateId] {
            let outputX = startX + CGFloat(maxLevel + 2) * horizontalSpacing
            let outputY = startY + CGFloat(gateLevels.last?.count ?? 0) * verticalSpacing / 2
            
            gates.append(LogicData.LogicGate(
                type: .output,
                inputs: [],
                position: CGPoint(x: outputX, y: outputY),
                label: "OUT"
            ))
            connections.append((from: outputGateIndex, to: gates.count - 1))
        }
        
        circuit = LogicData.Circuit(gates: gates, connections: connections)
        setupInputs()
    }
    
    private func setupInputs() {
        if let circuit = circuit {
            let inputGates = circuit.gates.filter { $0.type == .input }
            inputValues = Array(repeating: false, count: inputGates.count)
            // Sin esto, "outputValue" (que es lo que usa el LED de salida del circuito, a
            // diferencia de las demás compuertas que se recalculan solas con isGateActive) se
            // quedaba con el valor de la simulación anterior — o en false, la primera vez —
            // hasta que el usuario movía manualmente un interruptor. Al abrir el simulador o
            // cambiar de expresión el LED de salida podía mostrar un valor que no correspondía
            // para nada a las entradas actuales (todas en 0).
            simulateCircuit()
        }
    }
    
    private func simulateCircuit() {
        guard let circuit = circuit else { return }
        
        // Crear diccionario de valores de compuertas
        var gateValues: [Int: Bool] = [:]
        
        // Asignar valores de entrada
        for (index, gate) in circuit.gates.enumerated() {
            if gate.type == .input {
                let inputGates = circuit.gates.filter { $0.type == .input }
                if let inputIndex = inputGates.firstIndex(of: gate) {
                    gateValues[index] = inputIndex < inputValues.count ? inputValues[inputIndex] : false
                }
            }
        }
        
        // Evaluar compuertas en orden (esto está simplificado)
        for (index, gate) in circuit.gates.enumerated() {
            if gate.type != .input {
                var inputs: [Bool] = []
                for connection in circuit.connections {
                    if connection.to == index, let value = gateValues[connection.from] {
                        inputs.append(value)
                    }
                }
                
                // Antes ".not" leía "inputs[0]" directo. El botón nuevo de "eliminar variable"
                // puede quitar del diccionario "variables" una letra (p. ej. "D") que la
                // expresión sigue usando (p. ej. "¬D") — generateCircuit() ya no encuentra esa
                // variable en la lista activa, así que arma la compuerta NOT correspondiente sin
                // ninguna conexión de entrada. Con "inputs" vacío, "inputs[0]" tronaba la app con
                // "Index out of range" apenas se tocaba "-". Ahora, si a una compuerta le falta
                // la entrada (variable eliminada o no definida), se asume "false" — igual que ya
                // se hace en el analizador de expresiones para una variable no definida — en vez
                // de reventar.
                switch gate.type {
                case .and:
                    gateValues[index] = inputs.allSatisfy { $0 }
                case .or:
                    gateValues[index] = inputs.contains(true)
                case .not:
                    gateValues[index] = !(inputs.first ?? false)
                case .nand:
                    gateValues[index] = !inputs.allSatisfy { $0 }
                case .nor:
                    gateValues[index] = !inputs.contains(true)
                case .xor:
                    gateValues[index] = inputs.filter { $0 }.count % 2 == 1
                case .xnor:
                    gateValues[index] = inputs.filter { $0 }.count % 2 == 0
                case .output:
                    if let input = inputs.first {
                        outputValue = input
                    }
                case .input:
                    // Este caso ya fue manejado antes
                    break
                }
            }
        }
    }
}

// MARK: - Previews
struct BooleanLogicView_Previews: PreviewProvider {
    static var previews: some View {
        BooleanLogicView()
    }
}
