import SwiftUI

// MARK: - Modelos de Datos
struct Variable: Identifiable, Equatable {
    let id = UUID()
    let name: String
    var value: Bool
}

enum ComponentType: String, CaseIterable, Equatable {
    case input = "Entrada"
    case output = "Salida"
    case andGate = "AND"
    case orGate = "OR"
    case notGate = "NOT"
}

struct CircuitComponent: Identifiable, Equatable {
    let id = UUID()
    let type: ComponentType
    let name: String
    var position: CGPoint
    var connectedTo: [UUID]
    var value: Bool

    init(type: ComponentType, name: String, position: CGPoint, connectedTo: [UUID] = [], value: Bool = false) {
        self.type = type
        self.name = name
        self.position = position
        self.connectedTo = connectedTo
        self.value = value
    }
}

// MARK: - Motor compartido: evaluación del circuito, minitérminos y ecuación
//
// Antes había DOS motores de evaluación distintos y a medias: uno dentro de CircuitCanvas (que
// solo recorría las compuertas alcanzables desde una SALIDA o una OR, así que cualquier
// compuerta que todavía no llegara a una salida se quedaba sin evaluar) y otro método vacío en
// DigitalLogicView ("Implementado en CircuitCanvas") que literalmente no hacía nada — por eso
// cualquier circuito generado desde Karnaugh o Ecuación se veía siempre "apagado" hasta que se
// abría la pestaña de Circuito. Además, la tabla de minitérminos y la ecuación booleana estaban
// escritas a mano solo para "A", "B" y "C": cualquier otra variable (como la "D" que el propio
// teclado de símbolos ya mostraba) se ignoraba por completo. Ahora hay un solo motor —
// compartido por las tres pestañas— que evalúa el circuito completo (recorriendo TODAS las
// compuertas, no solo las conectadas a una salida), prueba las 2^n combinaciones posibles de 1
// a 5 variables para obtener los minitérminos reales, y arma la ecuación minimizada con el
// mismo Quine-McCluskey que ya usa Lógica Booleana (structs `QMTerm`/`QuineMcCluskey` definidos
// en LogicaBooleanaView.swift, reutilizados aquí tal cual).

/// Evalúa un circuito completo (recorrido topológico desde cada componente, no solo desde la
/// salida) y devuelve el valor de la salida. Actualiza en el sitio el valor de cada compuerta,
/// para que la vista siempre pueda mostrar cuál está encendida.
@discardableResult
func evaluateCircuitComponents(_ components: inout [CircuitComponent]) -> Bool {
    for i in components.indices where components[i].type != .input {
        components[i].value = false
    }

    var order: [UUID] = []
    var seen = Set<UUID>()
    func visit(_ id: UUID) {
        guard !seen.contains(id) else { return }
        seen.insert(id)
        if let component = components.first(where: { $0.id == id }) {
            for inputId in component.connectedTo {
                visit(inputId)
            }
        }
        order.append(id)
    }
    for component in components {
        visit(component.id)
    }

    var outputValue = false
    for id in order {
        guard let index = components.firstIndex(where: { $0.id == id }) else { continue }
        switch components[index].type {
        case .input:
            continue
        case .notGate:
            if let inputId = components[index].connectedTo.first,
               let input = components.first(where: { $0.id == inputId }) {
                components[index].value = !input.value
            }
        case .andGate:
            let inputs = components[index].connectedTo.compactMap { iid in components.first { $0.id == iid }?.value }
            components[index].value = !inputs.isEmpty && inputs.allSatisfy { $0 }
        case .orGate:
            let inputs = components[index].connectedTo.compactMap { iid in components.first { $0.id == iid }?.value }
            components[index].value = inputs.contains(true)
        case .output:
            if let inputId = components[index].connectedTo.first,
               let input = components.first(where: { $0.id == inputId }) {
                components[index].value = input.value
                outputValue = input.value
            }
        }
    }
    return outputValue
}

/// Prueba las 2^n combinaciones de las variables activas (1 a 5) sobre una COPIA del circuito
/// (los arreglos de struct en Swift se copian, así que esto nunca toca el circuito real) y
/// devuelve el conjunto real de minitérminos que produce.
func computeMinterms(components: [CircuitComponent], variableNames: [String]) -> Set<Int> {
    let n = variableNames.count
    guard n >= 1, n <= 5 else { return [] }

    var working = components
    var result = Set<Int>()
    for m in 0..<(1 << n) {
        for (i, name) in variableNames.enumerated() {
            if let idx = working.firstIndex(where: { $0.name == name && $0.type == .input }) {
                working[idx].value = ((m >> (n - 1 - i)) & 1) == 1
            }
        }
        if evaluateCircuitComponents(&working) {
            result.insert(m)
        }
    }
    return result
}

/// Arma la ecuación booleana minimizada (notación "A'", "·", "+") a partir de un conjunto de
/// minitérminos, usando el mismo Quine-McCluskey de Lógica Booleana.
func equationString(fromMinterms minterms: Set<Int>, variableNames: [String]) -> String {
    let n = variableNames.count
    guard n >= 1 else { return "f = 0" }
    if minterms.isEmpty { return "f = 0" }
    if minterms.count == (1 << n) { return "f = 1" }

    let primes = QuineMcCluskey.primeImplicants(minterms: Array(minterms), variableCount: n)
    let (essential, supplementary) = QuineMcCluskey.selectCover(primeImplicants: primes, minterms: Array(minterms))
    let terms = (essential + supplementary).map { term -> String in
        let literals: [String] = term.bits.enumerated().compactMap { (i, bit) in
            guard let b = bit else { return nil }
            return b == 1 ? variableNames[i] : "\(variableNames[i])'"
        }
        return literals.isEmpty ? "1" : literals.joined(separator: "·")
    }
    return "f = " + terms.sorted().joined(separator: " + ")
}

/// Interpreta una ecuación en notación "A·B + A'·C" (o "AB + A'C", con o sin "·") contra la
/// lista real de variables activas, y devuelve el conjunto de minitérminos que representa.
/// Antes esto solo reconocía "A", "B" y "C" escritos a mano; ahora funciona con cualquier
/// subconjunto de 1 a 5 variables y con ecuaciones tan largas como se quiera.
func mintermsFromEquation(_ equation: String, variableNames: [String]) -> Set<Int> {
    let n = variableNames.count
    guard n >= 1 else { return [] }

    var cleaned = equation.replacingOccurrences(of: " ", with: "")
    if let range = cleaned.range(of: "f=") {
        cleaned.removeSubrange(cleaned.startIndex..<range.upperBound)
    }

    if cleaned.isEmpty || cleaned == "0" { return [] }
    if cleaned == "1" { return Set(0..<(1 << n)) }

    var minterms = Set<Int>()
    for rawTerm in cleaned.components(separatedBy: "+") {
        let term = rawTerm.replacingOccurrences(of: "·", with: "")
        guard !term.isEmpty else { continue }
        if term == "0" { continue }
        if term == "1" { minterms.formUnion(0..<(1 << n)); continue }

        var fixedBits: [Int?] = Array(repeating: nil, count: n)
        var idx = term.startIndex
        while idx < term.endIndex {
            let letter = String(term[idx])
            var next = term.index(after: idx)
            guard let varIndex = variableNames.firstIndex(of: letter) else {
                idx = next
                continue
            }
            var isNegated = false
            if next < term.endIndex, term[next] == "'" {
                isNegated = true
                next = term.index(after: next)
            }
            fixedBits[varIndex] = isNegated ? 0 : 1
            idx = next
        }
        guard fixedBits.contains(where: { $0 != nil }) else { continue }

        for m in 0..<(1 << n) {
            var matches = true
            for i in 0..<n {
                if let fixed = fixedBits[i] {
                    let bitPos = n - 1 - i
                    if ((m >> bitPos) & 1) != fixed { matches = false; break }
                }
            }
            if matches { minterms.insert(m) }
        }
    }
    return minterms
}

// MARK: - Mapa de Karnaugh de 1 a 5 variables
//
// Antes el mapa estaba escrito a mano para exactamente 3 variables (A, B, C) con una cuadrícula
// fija de 2x4 y encabezados literales ("B'C'", "B'C"...). Esto generaliza esa misma
// distribución — fila = primera(s) variable(s), columna = siguiente(s), y para 5 variables una
// "capa" con la última — reutilizando `karnaughGrayOrder` (definido en LogicaBooleanaView.swift)
// para que el resultado sea consistente con el resto de la app.
func kmapDimensions(for n: Int) -> (rows: Int, cols: Int, hasLayer: Bool) {
    switch n {
    case 1: return (1, 2, false)
    case 2: return (2, 2, false)
    case 3: return (2, 4, false)
    case 4: return (4, 4, false)
    default: return (4, 4, true) // 5 variables
    }
}

func kmapMinterm(row: Int, column: Int, layer: Int, variableCount n: Int) -> Int {
    switch n {
    case 1:
        return column
    case 2:
        return (row << 1) | column
    case 3:
        return (row << 2) | karnaughGrayOrder[column]
    default: // 4 o 5
        let ab = karnaughGrayOrder[row]
        let cd = karnaughGrayOrder[column]
        return n == 5 ? (ab << 3) | (cd << 1) | layer : (ab << 2) | cd
    }
}

func kmapRowLabel(_ row: Int, variableCount n: Int, variableNames: [String]) -> String {
    switch n {
    case 1:
        return ""
    case 2, 3:
        return row == 0 ? "\(variableNames[0])'" : variableNames[0]
    default: // 4, 5
        let bit0 = (karnaughGrayOrder[row] >> 1) & 1
        let bit1 = karnaughGrayOrder[row] & 1
        let a = bit0 == 1 ? variableNames[0] : "\(variableNames[0])'"
        let b = bit1 == 1 ? variableNames[1] : "\(variableNames[1])'"
        return a + b
    }
}

func kmapColumnLabel(_ column: Int, variableCount n: Int, variableNames: [String]) -> String {
    switch n {
    case 1:
        return column == 0 ? "\(variableNames[0])'" : variableNames[0]
    case 2:
        return column == 0 ? "\(variableNames[1])'" : variableNames[1]
    case 3:
        let bit0 = (karnaughGrayOrder[column] >> 1) & 1
        let bit1 = karnaughGrayOrder[column] & 1
        let a = bit0 == 1 ? variableNames[1] : "\(variableNames[1])'"
        let b = bit1 == 1 ? variableNames[2] : "\(variableNames[2])'"
        return a + b
    default: // 4, 5
        let bit0 = (karnaughGrayOrder[column] >> 1) & 1
        let bit1 = karnaughGrayOrder[column] & 1
        let a = bit0 == 1 ? variableNames[2] : "\(variableNames[2])'"
        let b = bit1 == 1 ? variableNames[3] : "\(variableNames[3])'"
        return a + b
    }
}

// MARK: - Vistas de Componentes
//
// Antes cada cable se dibujaba como una simple línea recta de CENTRO a CENTRO entre dos
// compuertas. El problema: en cuanto había 3 o más compuertas medio alineadas (algo muy común
// al ir armando un circuito), una línea que en realidad iba de una compuerta A hacia otra C
// podía pasar visualmente muy cerca — o incluso justo por encima — de una compuerta B de en
// medio, sin estar conectada a ella en absoluto. Al arrastrar B, esa línea de A a C se veía
// "despegarse" de B, dando la impresión de que se había roto una conexión que en realidad nunca
// existió entre B y esa línea. Ahora los cables no salen del centro de la compuerta sino de sus
// "pines" reales (entrada/salida) en el borde de su símbolo — igual que en un diagrama de
// circuitos de verdad — y se dibujan en ángulo recto (horizontal-vertical-horizontal) en vez de
// en diagonal, así que un cable nunca puede confundirse visualmente con una compuerta por la que
// simplemente pasa cerca.
struct ConnectionView: View {
    let from: CGPoint
    let to: CGPoint
    let isActive: Bool

    private var color: Color { isActive ? .green : .gray }

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: from)
                let midX = (from.x + to.x) / 2
                path.addLine(to: CGPoint(x: midX, y: from.y))
                path.addLine(to: CGPoint(x: midX, y: to.y))
                path.addLine(to: to)
            }
            .stroke(color, lineWidth: 2)

            // Antes el cable era solo la línea: en cuanto dos compuertas quedaban cerca (por
            // ejemplo dos AND encadenadas para un mismo término), el tramo de cable entre ellas
            // era tan corto que se perdía contra los propios bordes de las compuertas y parecía
            // que estuvieran simplemente tocándose en vez de conectadas. Estos puntitos marcan
            // exactamente el pin de salida y el de entrada, como en un diagrama de circuito real,
            // para que se note claramente dónde empieza y dónde termina cada conexión.
            Circle().fill(color).frame(width: 6, height: 6).position(from)
            Circle().fill(color).frame(width: 6, height: 6).position(to)
        }
    }
}

/// Punto exacto (relativo al centro de la compuerta) donde "sale" su señal — el pin de salida —
/// según la forma real de su símbolo. Se usa para que los cables salgan del borde del símbolo, no
/// de su centro.
func outputPinOffset(for type: ComponentType) -> CGSize {
    switch type {
    case .input: return CGSize(width: 20, height: 0)
    case .andGate, .orGate: return CGSize(width: 30, height: 0)
    case .notGate: return CGSize(width: 27, height: 0)
    case .output: return .zero
    }
}

/// Puntos (relativos al centro) donde "entra" la señal — los pines de entrada — según la forma
/// real del símbolo. AND/OR aceptan hasta 2 entradas (una arriba y otra abajo, como en cualquier
/// diagrama de circuitos); NOT y Salida solo aceptan una.
func inputPinOffsets(for type: ComponentType) -> [CGSize] {
    switch type {
    case .andGate, .orGate:
        return [CGSize(width: -28, height: -10), CGSize(width: -28, height: 10)]
    case .notGate:
        return [CGSize(width: -17, height: 0)]
    case .output:
        return [CGSize(width: -20, height: 0)]
    case .input:
        return []
    }
}

func outputPin(of component: CircuitComponent) -> CGPoint {
    let offset = outputPinOffset(for: component.type)
    return CGPoint(x: component.position.x + offset.width, y: component.position.y + offset.height)
}

func inputPin(of component: CircuitComponent, at index: Int) -> CGPoint {
    let offsets = inputPinOffsets(for: component.type)
    let offset = offsets.indices.contains(index) ? offsets[index] : .zero
    return CGPoint(x: component.position.x + offset.width, y: component.position.y + offset.height)
}

/// Forma clásica de una compuerta AND: borde plano a la izquierda y una punta semicircular a la
/// derecha (la "D" que se usa en cualquier diagrama de circuitos digitales).
struct AndGateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.height / 2
        let straightX = rect.maxX - radius
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: straightX, y: rect.minY))
        // "clockwise" en SwiftUI se evalúa en un sistema de coordenadas con el eje Y invertido
        // (crece hacia abajo), así que barrer de -90° a 90° con "clockwise: true" en realidad
        // dibuja el arco por el lado LARGO (pasando por 180°, hacia la izquierda) en vez del lado
        // corto (pasando por 0°, hacia la derecha) — por eso la compuerta AND se veía con el
        // bulto curvo mordiendo hacia adentro, del lado de las entradas, en vez de sobresalir del
        // lado de la salida. Con "clockwise: false" el arco toma el camino corto correcto y
        // sobresale hacia la derecha, formando la "D" real de la compuerta AND.
        path.addArc(
            center: CGPoint(x: straightX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Forma clásica de una compuerta OR: borde trasero cóncavo (curvado hacia adentro) y una punta
/// curva a la derecha.
struct OrGateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: rect.minX + rect.height * 0.35, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.minY)
        )
        return path
    }
}

/// Forma clásica de una compuerta NOT: un triángulo apuntando a la derecha (la burbuja de
/// negación se dibuja aparte, justo después de la punta).
struct NotGateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct CircuitComponentView: View {
    @Environment(\.colorScheme) var colorScheme
    let component: CircuitComponent
    let isSelected: Bool
    let onTap: () -> Void
    let onDrag: (CGPoint) -> Void
    let onToggleValue: () -> Void
    let onDelete: () -> Void

    // El "salto" al arrastrar (una compuerta que termina lejísimos de donde la soltaste, a veces
    // pegada a una esquina) venía de aquí: "value.location" de un DragGesture da la posición del
    // dedo relativa al ESPACIO LOCAL de ESTA MISMA vista — y esta vista se mueve en cada
    // fotograma porque el padre la reposiciona con ".position(component.position)" apenas
    // "onDrag" actualiza esa posición. Como el sistema de coordenadas se movía debajo del dedo en
    // cada actualización, la posición calculada se iba acumulando mal y la compuerta terminaba en
    // cualquier parte. La forma correcta (y la que usa cualquier "arrastrar para mover" en
    // SwiftUI) es anclar la posición ORIGINAL al iniciar el arrastre y sumarle
    // "value.translation" — el desplazamiento total del dedo desde que empezó el gesto, que
    // SIEMPRE se mide desde el punto de partida y no cambia aunque la vista se mueva.
    @State private var dragAnchor: CGPoint? = nil

    // Antes conectar dos compuertas requería mantener presionado para abrir un menú, tocar
    // "Conectar desde aquí" y LUEGO arrastrar hasta la otra compuerta — pero cada compuerta ya
    // tenía su PROPIO gesto de arrastre para poder moverla, así que arrastrar hasta encima de la
    // compuerta destino simplemente la movía a ella en vez de completar el cable. Por eso, al
    // tocar la entrada A y arrastrar hasta una compuerta AND, nunca quedaban conectadas. Ahora
    // conectar es "tocar el origen, tocar el destino" (dos toques simples, sin arrastrar): un
    // solo toque arma o completa un cable, y un doble toque en una entrada cambia su valor.
    var body: some View {
        Group {
            switch component.type {
            case .input:
                inputView
            case .output:
                outputView
            case .andGate:
                andGateView
            case .orGate:
                orGateView
            case .notGate:
                notGateView
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let anchor = dragAnchor ?? component.position
                    if dragAnchor == nil {
                        dragAnchor = component.position
                    }
                    onDrag(CGPoint(x: anchor.x + value.translation.width, y: anchor.y + value.translation.height))
                }
                .onEnded { _ in
                    dragAnchor = nil
                }
        )
        .onTapGesture(count: 2, perform: onToggleValue)
        .onTapGesture(count: 1, perform: onTap)
        .contextMenu {
            if component.type != .input && component.type != .output {
                Button(role: .destructive, action: onDelete) {
                    Label("Eliminar", systemImage: "trash")
                }
            }
        }
    }

    private var inputView: some View {
        ZStack {
            Circle()
                .fill(component.value ? Color.green : Color.blue)
                .frame(width: 40, height: 40)

            VStack(spacing: 2) {
                Text(component.name)
                    .foregroundColor(.white)
                    .font(.caption)
                Text(component.value ? "1" : "0")
                    .foregroundColor(.white)
                    .font(.caption2)
            }
        }
        .overlay(
            Circle()
                .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 3)
        )
    }

    private var outputView: some View {
        ZStack {
            Circle()
                .fill(component.value ? Color.green : Color.red)
                .frame(width: 40, height: 40)

            VStack(spacing: 2) {
                Text("OUT")
                    .foregroundColor(.white)
                    .font(.caption)
                Text(component.value ? "1" : "0")
                    .foregroundColor(.white)
                    .font(.caption2)
            }
        }
        .overlay(
            Circle()
                .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 3)
        )
    }

    // Antes cada compuerta era simplemente un rectángulo con su nombre escrito adentro ("AND",
    // "OR", "NOT") — funcional, pero no se parecía en nada al símbolo real que se enseña en un
    // diagrama de circuitos. Ahora AND, OR y NOT usan su forma clásica (la "D" del AND, el
    // "escudo" curvo del OR, el triángulo con burbuja del NOT), y solo se conserva un pequeño
    // indicador de 0/1 para poder seguir viendo en vivo el estado de la simulación.
    private var andGateView: some View {
        let width: CGFloat = 60
        let height: CGFloat = 42
        return ZStack {
            AndGateShape()
                .fill(component.value ? Color.green.opacity(0.3) : (colorScheme == .dark ? Color.black : Color.white))
            AndGateShape()
                .stroke(isSelected ? Color.yellow : Color.orange, lineWidth: 2.5)
            Text(component.value ? "1" : "0")
                .font(.system(size: 11, weight: .bold))
                .offset(x: -6)
        }
        .frame(width: width, height: height)
    }

    private var orGateView: some View {
        let width: CGFloat = 60
        let height: CGFloat = 42
        return ZStack {
            OrGateShape()
                .fill(component.value ? Color.green.opacity(0.3) : (colorScheme == .dark ? Color.black : Color.white))
            OrGateShape()
                .stroke(isSelected ? Color.yellow : Color.purple, lineWidth: 2.5)
            Text(component.value ? "1" : "0")
                .font(.system(size: 11, weight: .bold))
                .offset(x: 2)
        }
        .frame(width: width, height: height)
    }

    private var notGateView: some View {
        let width: CGFloat = 30
        let height: CGFloat = 34
        let bubble: CGFloat = 12
        return VStack(spacing: 1) {
            ZStack {
                NotGateShape()
                    .fill(component.value ? Color.green.opacity(0.3) : (colorScheme == .dark ? Color.black : Color.white))
                    .frame(width: width, height: height)
                NotGateShape()
                    .stroke(isSelected ? Color.yellow : Color.green, lineWidth: 2.5)
                    .frame(width: width, height: height)
                Circle()
                    .fill(colorScheme == .dark ? Color.black : Color.white)
                    .frame(width: bubble, height: bubble)
                    .overlay(Circle().stroke(isSelected ? Color.yellow : Color.green, lineWidth: 2.5))
                    .offset(x: width / 2 + bubble / 2 - 1)
            }
            .frame(width: width + bubble, height: height)
            Text(component.value ? "1" : "0")
                .font(.system(size: 9, weight: .bold))
        }
    }
}

// MARK: - CircuitCanvas
struct CircuitCanvas: View {
    @Binding var components: [CircuitComponent]
    @Binding var selectedComponent: UUID?
    @Binding var connectionStart: UUID?
    @Binding var outputValue: Bool
    @Binding var minterms: Set<Int>
    @Binding var booleanEquation: String
    @Binding var variables: [Variable]
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    @State private var canvasSize: CGSize = CGSize(width: 1500, height: 1000)
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fondo con cuadrícula
                gridBackground
                    .frame(width: canvasSize.width, height: canvasSize.height)

                // Contenido del circuito
                circuitContent
                    .frame(width: canvasSize.width, height: canvasSize.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if connectionStart == nil {
                            let translation = value.translation
                            offset.width = lastOffset.width + translation.width / scale
                            offset.height = lastOffset.height + translation.height / scale
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = lastScale * value
                        scale = max(min(newScale, 3.0), 0.5)
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
            )
            .gesture(
                TapGesture(count: 1)
                    .onEnded {
                        // Tocar el fondo vacío deselecciona y cancela cualquier cable en curso.
                        selectedComponent = nil
                        connectionStart = nil
                    }
            )
            // Antes "canvasSize" se quedaba fijo en 1500x1000 sin importar el tamaño real que el
            // contenedor padre le daba a este lienzo (que crece dinámicamente para que quepan
            // circuitos grandes). Cuando el lienzo terminaba siendo más ancho o alto que eso, este
            // ZStack (dibujado siempre a 1500x1000) quedaba centrado dentro de un espacio mayor en
            // vez de ocupar todo el espacio disponible — así que las compuertas parecían
            // "salirse" del cuadro cuadriculado o desalinearse en cuanto el lienzo crecía. Ahora
            // "canvasSize" siempre se mantiene igual al tamaño real que este lienzo tiene
            // disponible, así que el fondo, el contenido y los límites de arrastre (ver
            // handleDrag) siempre coinciden.
            .onAppear {
                canvasSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                canvasSize = newSize
            }
        }
    }

    private var gridBackground: some View {
        Path { path in
            let gridSize: CGFloat = 20
            let rows = Int(canvasSize.height / gridSize)
            let cols = Int(canvasSize.width / gridSize)

            // Líneas verticales
            for col in 0...cols {
                let x = CGFloat(col) * gridSize
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
            }

            // Líneas horizontales
            for row in 0...rows {
                let y = CGFloat(row) * gridSize
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
            }
        }
        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
    }

    private var circuitContent: some View {
        ZStack {
            // Conexiones entre componentes — antes salían del CENTRO de cada compuerta, lo que
            // podía confundirse con una compuerta vecina por la que la línea simplemente pasaba
            // cerca. Ahora salen del pin real (entrada/salida) de cada símbolo.
            ForEach(components) { component in
                ForEach(Array(component.connectedTo.enumerated()), id: \.offset) { index, connectedId in
                    if let connectedComponent = components.first(where: { $0.id == connectedId }) {
                        ConnectionView(
                            from: outputPin(of: connectedComponent),
                            to: inputPin(of: component, at: index),
                            isActive: connectedComponent.value
                        )
                    }
                }
            }

            // Componentes del circuito
            ForEach(components) { component in
                CircuitComponentView(
                    component: component,
                    isSelected: selectedComponent == component.id,
                    onTap: {
                        handleTap(component: component)
                    },
                    onDrag: { location in
                        handleDrag(component: component, location: location)
                    },
                    onToggleValue: {
                        handleToggleValue(component: component)
                    },
                    onDelete: {
                        deleteComponent(component.id)
                    }
                )
                .position(component.position)
            }
        }
    }

    // Funciones de manejo de interacción
    //
    // Antes armar un cable necesitaba: mantener presionado para abrir un menú contextual, tocar
    // "Conectar desde aquí" y luego ARRASTRAR hasta la compuerta destino — pero cada compuerta ya
    // tenía su propio gesto de arrastre para poder reposicionarla, así que ese arrastre terminaba
    // moviendo la compuerta destino en vez de completar la conexión. Ahora conectar es "tocar el
    // origen, tocar el destino": un solo toque en un componente lo arma como inicio del cable (se
    // resalta en amarillo, reutilizando el mismo aro de selección); tocar un componente distinto
    // completa el cable si es una conexión válida (y si no lo es, simplemente no pasa nada y el
    // origen se queda armado para intentar con otro destino); tocar el mismo componente armado, o
    // el fondo vacío, cancela el cable en curso. Mover una compuerta arrastrándola sigue
    // funcionando exactamente igual que antes.
    private func handleTap(component: CircuitComponent) {
        if let startId = connectionStart {
            if startId == component.id {
                // Tocar el mismo componente armado cancela el cable en curso.
                connectionStart = nil
                selectedComponent = nil
                return
            }
            if connectComponents(from: startId, to: component.id) {
                connectionStart = nil
                selectedComponent = nil
            }
            // Si la conexión no era válida (por ejemplo, la compuerta destino ya tiene todas sus
            // entradas ocupadas) el origen se deja armado para poder tocar otro destino.
            return
        }

        selectedComponent = component.id
        connectionStart = component.id
    }

    private func handleToggleValue(component: CircuitComponent) {
        guard component.type == .input,
              let index = components.firstIndex(where: { $0.id == component.id }) else { return }
        components[index].value.toggle()
        updateVariable(named: component.name, value: components[index].value)
        updateAllRepresentations()
    }

    private func handleDrag(component: CircuitComponent, location: CGPoint) {
        // Antes esto exigía que el componente ya estuviera "seleccionado" (por un toque previo)
        // para poder arrastrarlo. Pero ahora un solo toque arma o completa un cable — así que
        // exigir selección previa para arrastrar chocaba con eso (arrastrar una compuerta que
        // todavía no se había tocado no hacía nada). Un arrastre real (el dedo se mueve) y un
        // toque (el dedo no se mueve) son gestos distintos y SwiftUI ya los distingue solo, así
        // que aquí simplemente se reposiciona sin depender de ninguna selección previa.
        //
        // Antes tampoco había ningún límite: se podía arrastrar una compuerta fuera del área
        // visible (incluso a coordenadas negativas), donde quedaba inalcanzable — el ScrollView
        // no permite desplazarse hacia coordenadas negativas, así que esa compuerta se "perdía".
        // Ahora la posición siempre se recorta para quedar dentro del lienzo actual.
        guard let index = components.firstIndex(where: { $0.id == component.id }) else { return }
        let margin: CGFloat = 30
        let maxX = max(canvasSize.width - margin, margin)
        let maxY = max(canvasSize.height - margin, margin)
        components[index].position = CGPoint(
            x: min(max(location.x, margin), maxX),
            y: min(max(location.y, margin), maxY)
        )
    }

    private func updateVariable(named name: String, value: Bool) {
        if let index = variables.firstIndex(where: { $0.name == name }) {
            variables[index].value = value
        }
    }

    private func deleteComponent(_ id: UUID) {
        components.removeAll { $0.id == id }
        for i in components.indices {
            components[i].connectedTo.removeAll { $0 == id }
        }
        updateAllRepresentations()
    }

    @discardableResult
    private func connectComponents(from startId: UUID, to endId: UUID) -> Bool {
        guard let startComponent = components.first(where: { $0.id == startId }),
              let endIndex = components.firstIndex(where: { $0.id == endId }),
              isValidConnection(from: startComponent, to: components[endIndex]) else { return false }

        components[endIndex].connectedTo.append(startId)
        updateAllRepresentations()
        return true
    }

    private func isValidConnection(from: CircuitComponent, to: CircuitComponent) -> Bool {
        if to.type == .input { return false }
        if createsCycle(start: from.id, end: to.id) { return false }

        switch to.type {
        case .andGate, .orGate:
            return to.connectedTo.count < 2
        case .notGate:
            return to.connectedTo.isEmpty
        case .output:
            return to.connectedTo.isEmpty
        default:
            return true
        }
    }

    private func createsCycle(start: UUID, end: UUID) -> Bool {
        var visited = Set<UUID>()
        var queue = [end]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current == start { return true }

            if !visited.contains(current), let component = components.first(where: { $0.id == current }) {
                visited.insert(current)
                queue.append(contentsOf: component.connectedTo)
            }
        }
        return false
    }

    // Antes esto llamaba a "getEvaluationOrder()" (que solo recorría desde una SALIDA o una OR,
    // dejando compuertas enteras sin evaluar) y luego armaba la ecuación mirando el nombre de la
    // compuerta y su valor de EJECUCIÓN actual — así que la "ecuación" cambiaba sola cada vez
    // que se movía un interruptor, y las variables fuera de A/B/C se ignoraban. Ahora todo pasa
    // por el mismo motor compartido (evaluateCircuitComponents + computeMinterms +
    // equationString), así que la ecuación siempre es la fórmula real del circuito, sin importar
    // cuántas variables tenga (1 a 5) ni el estado actual de los interruptores.
    private func updateAllRepresentations() {
        evaluateCircuit()
        let names = variables.map { $0.name }
        minterms = computeMinterms(components: components, variableNames: names)
        booleanEquation = equationString(fromMinterms: minterms, variableNames: names)
    }

    private func evaluateCircuit() {
        outputValue = evaluateCircuitComponents(&components)
    }
}

// MARK: - Vista Principal
struct DigitalLogicView: View {
    enum InputMode: String, CaseIterable {
        case karnaugh = "Mapa K"
        case equation = "Ecuación"
        case circuit = "Circuito"
    }

    @State private var inputMode: InputMode = .circuit
    @State private var variables: [Variable] = [
        Variable(name: "A", value: false),
        Variable(name: "B", value: false),
        Variable(name: "C", value: false)
    ]

    // Antes había un arreglo "kmapValues: [[Bool]]" de tamaño fijo 2x4 (solo servía para 3
    // variables) que había que mantener sincronizado a mano con la ecuación y el circuito. Ahora
    // el conjunto de minitérminos ES la función booleana (funciona igual para 1 a 5 variables), y
    // tanto el mapa de Karnaugh como la ecuación se calculan a partir de él bajo demanda.
    @State private var minterms: Set<Int> = []
    @State private var kmapLayer: Int = 0

    @State private var booleanEquation = "f = "
    @State private var circuitComponents: [CircuitComponent] = []
    @State private var outputValue: Bool = false
    @State private var selectedComponent: UUID? = nil
    @State private var connectionStart: UUID? = nil
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    modePicker
                    editorSection
                    circuitMiniView
                    representationsSection
                    outputSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitle("Simulador Lógico", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: resetAll) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reiniciar")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        // Antes, al abrir la vista, se creaban de una vez las entradas de las 3 variables por
        // defecto (A, B, C) sobre el lienzo de Circuito — así que ese lienzo nunca se veía
        // realmente vacío, aunque el usuario no hubiera tocado nada todavía. Ahora el lienzo
        // arranca sin ninguna compuerta: Karnaugh y Ecuación siguen mostrando sus 3 variables por
        // defecto (mapa en 0 y "f = ") porque esas dos pestañas no dependen de que haya
        // compuertas físicas, y en Circuito el usuario arma todo desde cero con la paleta —
        // "Entrada" coloca primero las variables que ya existen pero aún no tienen compuerta
        // (empezando por A), y solo crea una variable nueva cuando ya no queda ninguna pendiente
        // (ver placeNextInput()).
    }

    // MARK: - Componentes UI

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Simulador de Circuitos Lógicos")
                .font(.largeTitle).bold()
                .foregroundColor(.blue)

            Text("Diseña circuitos digitales y visualiza sus representaciones")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modePicker: some View {
        Picker("Modo", selection: $inputMode) {
            ForEach(InputMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 8)
    }

    private var editorSection: some View {
        Group {
            switch inputMode {
            case .karnaugh:
                karnaughEditor
            case .equation:
                equationEditor
            case .circuit:
                circuitEditor
            }
        }
        .cardStyle()
    }

    // MARK: - Control de variables (1 a 5)
    //
    // Antes no existía ninguna forma de cambiar cuántas variables tenía la función: todo estaba
    // fijo a A, B y C. Este control (botones "+"/"-") deja agregar o quitar variables entre 1 y
    // 5, y mantiene sincronizadas las entradas del circuito para que las tres representaciones
    // (Karnaugh, Ecuación, Circuito) sigan siendo consistentes entre sí.
    private var variableCountControl: some View {
        HStack {
            Text("Variables:")
                .font(.subheadline)

            ForEach(variables) { v in
                Text(v.name)
                    .font(.subheadline.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(6)
            }

            Spacer()

            Button(action: removeVariable) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(variables.count > 1 ? .red : .gray)
            }
            .disabled(variables.count <= 1)

            Button(action: addVariable) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(variables.count < 5 ? .green : .gray)
            }
            .disabled(variables.count >= 5)
        }
        .padding(.horizontal, 4)
    }

    private func addVariable() {
        guard variables.count < 5 else { return }
        let nextLetter = String(UnicodeScalar(65 + variables.count)!)
        variables.append(Variable(name: nextLetter, value: false))

        if !circuitComponents.contains(where: { $0.name == nextLetter && $0.type == .input }) {
            circuitComponents.append(CircuitComponent(
                type: .input,
                name: nextLetter,
                position: CGPoint(x: 100, y: 100 + CGFloat(variables.count - 1) * 100),
                connectedTo: [],
                value: false
            ))
        }

        kmapLayer = 0
        refreshFromCircuit()
    }

    private func removeVariable() {
        guard variables.count > 1 else { return }
        let removedName = variables.removeLast().name

        if let index = circuitComponents.firstIndex(where: { $0.name == removedName && $0.type == .input }) {
            let removedId = circuitComponents[index].id
            circuitComponents.remove(at: index)
            for i in circuitComponents.indices {
                circuitComponents[i].connectedTo.removeAll { $0 == removedId }
            }
        }

        kmapLayer = 0
        refreshFromCircuit()
    }

    /// Coloca en el lienzo de Circuito la siguiente entrada disponible. Si ya existe una
    /// variable (de Karnaugh, Ecuación, o de una sesión anterior) que todavía no tiene una
    /// compuerta física en el lienzo, la coloca a ella primero — así, aunque el lienzo arranque
    /// vacío, la primera "Entrada" que se agrega siempre es "A", la segunda "B", y así
    /// sucesivamente. Solo crea una variable genuinamente nueva (mismo mecanismo que el botón
    /// "+" de Karnaugh) cuando todas las que ya existen están colocadas.
    private func placeNextInput() {
        if let pending = variables.first(where: { variable in
            !circuitComponents.contains(where: { $0.name == variable.name && $0.type == .input })
        }) {
            let position = findOptimalPosition(near: CGPoint(x: 150, y: 150), avoiding: circuitComponents)
            circuitComponents.append(CircuitComponent(
                type: .input,
                name: pending.name,
                position: position,
                connectedTo: [],
                value: false
            ))
            refreshFromCircuit()
            return
        }
        addVariable()
    }

    /// Recalcula minitérminos, ecuación y salida a partir del circuito actual — el mismo motor
    /// que usa CircuitCanvas, para que las tres pestañas nunca queden desincronizadas.
    private func refreshFromCircuit() {
        let names = variables.map { $0.name }
        outputValue = evaluateCircuitComponents(&circuitComponents)
        minterms = computeMinterms(components: circuitComponents, variableNames: names)
        booleanEquation = equationString(fromMinterms: minterms, variableNames: names)
    }

    // MARK: - Editor de Karnaugh (1 a 5 variables)
    private var karnaughEditor: some View {
        let n = variables.count
        let variableNames = variables.map { $0.name }
        let dims = kmapDimensions(for: n)

        return VStack(spacing: 12) {
            Text("Editor de Mapa de Karnaugh")
                .font(.headline)

            variableCountControl

            if dims.hasLayer {
                Picker("Capa", selection: $kmapLayer) {
                    Text("\(variableNames[4]) = 0").tag(0)
                    Text("\(variableNames[4]) = 1").tag(1)
                }
                .pickerStyle(.segmented)
            }

            kmapGrid(editable: true, cellSize: 60, headerSize: 30, n: n, variableNames: variableNames)

            HStack {
                Button("Todos 0") {
                    setAllKmapCells(to: false)
                }

                Button("Todos 1") {
                    setAllKmapCells(to: true)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    /// Cuadrícula de Karnaugh reutilizada tanto por el editor (con celdas tocables) como por la
    /// vista de solo lectura de la sección "Representaciones".
    private func kmapGrid(editable: Bool, cellSize: CGFloat, headerSize: CGFloat, n: Int, variableNames: [String]) -> some View {
        let dims = kmapDimensions(for: n)
        let layer = dims.hasLayer ? kmapLayer : 0

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: cellSize, height: headerSize)

                ForEach(0..<dims.cols, id: \.self) { col in
                    Text(kmapColumnLabel(col, variableCount: n, variableNames: variableNames))
                        .font(.caption2)
                        .frame(width: cellSize, height: headerSize)
                }
            }

            ForEach(0..<dims.rows, id: \.self) { row in
                HStack(spacing: 0) {
                    Text(kmapRowLabel(row, variableCount: n, variableNames: variableNames))
                        .font(.caption2)
                        .frame(width: cellSize, height: cellSize)

                    ForEach(0..<dims.cols, id: \.self) { col in
                        let m = kmapMinterm(row: row, column: col, layer: layer, variableCount: n)
                        let isOn = minterms.contains(m)

                        if editable {
                            Button(action: { toggleKmapCell(minterm: m) }) {
                                Text(isOn ? "1" : "0")
                                    .frame(width: cellSize, height: cellSize)
                                    .background(isOn ? Color.green.opacity(0.3) : Color(.systemBackground))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Text(isOn ? "1" : "0")
                                .frame(width: cellSize, height: cellSize)
                                .background(isOn ? Color.green.opacity(0.2) : Color(.systemBackground))
                        }
                    }
                }
            }
        }
    }

    private func toggleKmapCell(minterm: Int) {
        if minterms.contains(minterm) {
            minterms.remove(minterm)
        } else {
            minterms.insert(minterm)
        }
        booleanEquation = equationString(fromMinterms: minterms, variableNames: variables.map { $0.name })
        rebuildCircuitFromMinterms()
    }

    private func setAllKmapCells(to value: Bool) {
        let n = variables.count
        minterms = value ? Set(0..<(1 << n)) : []
        booleanEquation = equationString(fromMinterms: minterms, variableNames: variables.map { $0.name })
        rebuildCircuitFromMinterms()
    }

    // MARK: - Generación del circuito a partir de los minitérminos
    //
    // Antes esta función solo sabía construir un circuito para exactamente 3 variables (A, B,
    // C), con compuertas AND/OR de hasta 2 entradas armadas "a mano" por cada literal posible.
    // Ahora se apoya en los implicantes primos reales (Quine-McCluskey, ya usado en Lógica
    // Booleana) y encadena compuertas binarias las veces que hagan falta, así que funciona igual
    // de bien con 1 a 5 variables y con ecuaciones largas (muchos términos).
    private func rebuildCircuitFromMinterms() {
        let n = variables.count
        let variableNames = variables.map { $0.name }

        circuitComponents.removeAll { $0.type != .input }
        for (index, variable) in variables.enumerated() {
            if !circuitComponents.contains(where: { $0.name == variable.name && $0.type == .input }) {
                circuitComponents.append(CircuitComponent(
                    type: .input,
                    name: variable.name,
                    position: CGPoint(x: 100, y: 100 + CGFloat(index) * 100),
                    connectedTo: [],
                    value: false
                ))
            }
        }

        guard !minterms.isEmpty else {
            circuitComponents.append(CircuitComponent(type: .output, name: "OUT", position: CGPoint(x: 350, y: 250), connectedTo: [], value: false))
            refreshFromCircuit()
            return
        }

        if minterms.count == (1 << n), let firstInput = circuitComponents.first(where: { $0.type == .input }) {
            // f ≡ 1: con solo AND/OR/NOT no hay forma de representar una constante sin al menos
            // una entrada — se arma como (variable) OR (su negación), que siempre da 1.
            let notGate = CircuitComponent(type: .notGate, name: "NOT_\(firstInput.name)", position: CGPoint(x: 220, y: firstInput.position.y + 60), connectedTo: [], value: false)
            circuitComponents.append(notGate)
            connectComponents(from: firstInput.id, to: notGate.id)
            let orGate = CircuitComponent(type: .orGate, name: "OR_1", position: CGPoint(x: 380, y: firstInput.position.y + 30), connectedTo: [], value: false)
            circuitComponents.append(orGate)
            connectComponents(from: firstInput.id, to: orGate.id)
            connectComponents(from: notGate.id, to: orGate.id)
            let output = CircuitComponent(type: .output, name: "OUT", position: CGPoint(x: 560, y: firstInput.position.y + 30), connectedTo: [], value: false)
            circuitComponents.append(output)
            connectComponents(from: orGate.id, to: output.id)
            refreshFromCircuit()
            return
        }

        let primes = QuineMcCluskey.primeImplicants(minterms: Array(minterms), variableCount: n)
        let (essential, supplementary) = QuineMcCluskey.selectCover(primeImplicants: primes, minterms: Array(minterms))
        let terms = essential + supplementary

        var notGateCache: [String: UUID] = [:]
        var termOutputs: [UUID] = []
        var maxColumnReached: CGFloat = 260

        for (termIndex, term) in terms.enumerated() {
            let literalIndices = term.bits.enumerated().compactMap { (i, b) in b != nil ? i : nil }
            guard !literalIndices.isEmpty else { continue }

            var literalIds: [UUID] = []
            for i in literalIndices {
                guard let inputComp = circuitComponents.first(where: { $0.name == variableNames[i] && $0.type == .input }) else { continue }
                if term.bits[i] == 0 {
                    if let cached = notGateCache[variableNames[i]] {
                        literalIds.append(cached)
                    } else {
                        let notGate = CircuitComponent(
                            type: .notGate,
                            name: "NOT_\(variableNames[i])",
                            position: CGPoint(x: 200, y: inputComp.position.y),
                            connectedTo: [],
                            value: false
                        )
                        circuitComponents.append(notGate)
                        connectComponents(from: inputComp.id, to: notGate.id)
                        notGateCache[variableNames[i]] = notGate.id
                        literalIds.append(notGate.id)
                    }
                } else {
                    literalIds.append(inputComp.id)
                }
            }

            guard var currentId = literalIds.first else { continue }
            var column: CGFloat = 320
            for nextId in literalIds.dropFirst() {
                let andGate = CircuitComponent(
                    type: .andGate,
                    name: "AND_\(termIndex + 1)_\(Int(column))",
                    position: CGPoint(x: column, y: CGFloat(termIndex) * 120 + 180),
                    connectedTo: [],
                    value: false
                )
                circuitComponents.append(andGate)
                connectComponents(from: currentId, to: andGate.id)
                connectComponents(from: nextId, to: andGate.id)
                currentId = andGate.id
                column += 120
            }
            maxColumnReached = max(maxColumnReached, column)
            termOutputs.append(currentId)
        }

        guard var currentId = termOutputs.first else {
            circuitComponents.append(CircuitComponent(type: .output, name: "OUT", position: CGPoint(x: 350, y: 250), connectedTo: [], value: false))
            refreshFromCircuit()
            return
        }

        // Antes las compuertas encadenadas (varios AND de un mismo término, o varios OR
        // seguidos) quedaban separadas por solo 90pt. Con compuertas de 60pt de ancho eso dejaba
        // apenas 30pt de cable entre una y otra, así que a simple vista se veían amontonadas o
        // como si se tocaran en vez de estar claramente conectadas. 120pt deja un tramo de cable
        // holgado y visible entre cada par.
        let orColumn = maxColumnReached + 120
        var orY: CGFloat = 180
        var orIndex = 0
        for nextId in termOutputs.dropFirst() {
            orIndex += 1
            let orGate = CircuitComponent(
                type: .orGate,
                name: "OR_\(orIndex)",
                position: CGPoint(x: orColumn, y: orY),
                connectedTo: [],
                value: false
            )
            circuitComponents.append(orGate)
            connectComponents(from: currentId, to: orGate.id)
            connectComponents(from: nextId, to: orGate.id)
            currentId = orGate.id
            orY += 120
        }

        let output = CircuitComponent(type: .output, name: "OUT", position: CGPoint(x: orColumn + 120, y: 250), connectedTo: [], value: false)
        circuitComponents.append(output)
        connectComponents(from: currentId, to: output.id)

        refreshFromCircuit()
    }

    private func connectComponents(from: UUID, to: UUID) {
        guard let toIndex = circuitComponents.firstIndex(where: { $0.id == to }) else { return }

        if !circuitComponents[toIndex].connectedTo.contains(from) {
            circuitComponents[toIndex].connectedTo.append(from)
        }
    }

    // MARK: - Editor de Ecuación
    private var equationEditor: some View {
        VStack(spacing: 12) {
            Text("Editor de Ecuación")
                .font(.headline)

            HStack {
                Text("f =")
                    .font(.title2)
                    .frame(width: 40, alignment: .trailing)

                TextField("A·B + A'·C", text: $booleanEquation)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                    .padding(.vertical, 8)
                    .onChange(of: booleanEquation) { newValue in
                        parseEquation(newValue)
                    }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Antes esta fila de símbolos tenía "A", "B", "C", "D" escritos a mano, pero
                    // el analizador de la ecuación solo reconocía A, B y C — la "D" no hacía
                    // nada. Ahora la fila muestra exactamente las variables activas (1 a 5, las
                    // mismas que en Karnaugh/Circuito), así que todo botón corresponde a algo
                    // que la ecuación sabe interpretar.
                    ForEach(variables.map { $0.name } + ["(", ")", "'", "+", "·", "0", "1"], id: \.self) { symbol in
                        Button(action: {
                            booleanEquation += symbol
                        }) {
                            Text(symbol)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .frame(width: 36, height: 36)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }

                    Button(action: {
                        if !booleanEquation.isEmpty {
                            booleanEquation.removeLast()
                        }
                    }) {
                        Image(systemName: "delete.left")
                            .frame(width: 36, height: 36)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }

    private func parseEquation(_ equation: String) {
        minterms = mintermsFromEquation(equation, variableNames: variables.map { $0.name })
        // No se sobreescribe booleanEquation aquí: es justo lo que el usuario está escribiendo.
        rebuildCircuitFromMinterms()
    }

    // MARK: - Editor de Circuito
    private var circuitEditor: some View {
        VStack(spacing: 12) {
            Text("Editor de Circuito")
                .font(.headline)

            HStack {
                Button(action: zoomIn) {
                    Image(systemName: "plus.magnifyingglass")
                        .padding(8)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }

                Button(action: zoomOut) {
                    Image(systemName: "minus.magnifyingglass")
                        .padding(8)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }

                Button(action: resetView) {
                    Image(systemName: "arrow.uturn.left.circle")
                        .padding(8)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding(.horizontal, 8)

            // Antes la única pista era sobre mover el lienzo (arrastrar/zoom); no decía nada de
            // cómo conectar las compuertas entre sí, que es justo lo que costaba trabajo.
            VStack(alignment: .leading, spacing: 2) {
                Text("Arrastra una compuerta para moverla · Desliza con 1 dedo el fondo para recorrer el lienzo, 2 dedos para zoom")
                Text("Toca una compuerta y luego otra para conectarlas (se resalta en amarillo mientras esperas el destino) · Doble toque en una entrada para cambiar su valor")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)

            GeometryReader { geometry in
                // Antes el lienzo tenía un tamaño fijo de 1500x1000. Con varios términos y hasta
                // 5 variables el circuito generado puede crecer más que eso, y las últimas
                // compuertas quedaban fuera del área en la que el ScrollView puede desplazarse
                // — es decir, existían pero nunca se llegaban a ver. Ahora el lienzo crece según
                // la compuerta real más alejada, igual que en Lógica Booleana.
                let maxGateX = (circuitComponents.map { $0.position.x }.max() ?? 0) + 200
                let maxGateY = (circuitComponents.map { $0.position.y }.max() ?? 0) + 200
                let canvasWidth = max(geometry.size.width, max(1500, maxGateX))
                let canvasHeight = max(geometry.size.height, max(1000, maxGateY))

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    CircuitCanvas(
                        components: $circuitComponents,
                        selectedComponent: $selectedComponent,
                        connectionStart: $connectionStart,
                        outputValue: $outputValue,
                        minterms: $minterms,
                        booleanEquation: $booleanEquation,
                        variables: $variables,
                        scale: $scale,
                        offset: $offset
                    )
                    .frame(width: canvasWidth, height: canvasHeight)
                }
            }
            .frame(height: 400)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            componentPalette
        }
        .padding()
    }

    private func zoomIn() {
        withAnimation {
            scale = min(scale + 0.2, 3.0)
        }
    }

    private func zoomOut() {
        withAnimation {
            scale = max(scale - 0.2, 0.5)
        }
    }

    private func resetView() {
        withAnimation {
            scale = 1.0
            offset = .zero
        }
    }

    private var componentPalette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ComponentType.allCases, id: \.self) { type in
                    Button(action: { addGate(type: type) }) {
                        VStack {
                            Image(systemName: iconName(for: type))
                                .font(.system(size: 20))
                            Text(type.rawValue)
                                .font(.caption2)
                        }
                        .frame(width: 60, height: 50)
                        .background(color(for: type))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }
                    .contextMenu {
                        Button(action: {
                            addMultipleGates(type: type, count: 5)
                        }) {
                            Label("Agregar 5", systemImage: "plus.square.on.square")
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func addGate(type: ComponentType) {
        // Antes agregar una "Entrada" desde la paleta la nombraba "E1", "E2"... (la inicial de
        // "Entrada"), sin importar qué variables ya existían — así que el mapa de Karnaugh y la
        // ecuación (que buscan variables por nombre A, B, C...) nunca reconocían esa entrada
        // nueva. Ahora agregar una entrada desde aquí usa el mismo mecanismo de "Variables" que
        // el botón +/- de Karnaugh, así que siempre queda nombrada A, B, C, D o E y sincronizada
        // con las otras dos representaciones. Como el lienzo de Circuito ahora arranca vacío,
        // "Entrada" primero coloca las variables que ya existen pero todavía no tienen compuerta
        // en el lienzo (empezando por A) — ver placeNextInput() — y solo crea una variable nueva
        // cuando ya no queda ninguna pendiente.
        if type == .input {
            placeNextInput()
            return
        }

        let newName: String
        let basePosition: CGPoint

        switch type {
        case .input:
            newName = ""
            basePosition = .zero
        case .output:
            newName = "OUT"
            basePosition = CGPoint(x: 800, y: 225)
        case .andGate:
            newName = "AND\(circuitComponents.filter { $0.type == .andGate }.count + 1)"
            basePosition = CGPoint(x: 400, y: 150)
        case .orGate:
            newName = "OR\(circuitComponents.filter { $0.type == .orGate }.count + 1)"
            basePosition = CGPoint(x: 600, y: 225)
        case .notGate:
            newName = "NOT\(circuitComponents.filter { $0.type == .notGate }.count + 1)"
            basePosition = CGPoint(x: 400, y: 300)
        }

        let position = findOptimalPosition(near: basePosition, avoiding: circuitComponents)

        let newComponent = CircuitComponent(
            type: type,
            name: newName,
            position: position,
            connectedTo: [],
            value: false
        )
        circuitComponents.append(newComponent)
        selectedComponent = newComponent.id
        refreshFromCircuit()
    }

    private func addMultipleGates(type: ComponentType, count: Int) {
        for _ in 0..<count {
            addGate(type: type)
        }
    }

    private func findOptimalPosition(near point: CGPoint, avoiding existingComponents: [CircuitComponent]) -> CGPoint {
        var position = point
        let gridSize: CGFloat = 60
        var attempts = 0
        var spiralRadius: CGFloat = 0

        while existingComponents.contains(where: { component in
            abs(component.position.x - position.x) < gridSize &&
            abs(component.position.y - position.y) < gridSize
        }) && attempts < 20 {
            attempts += 1
            spiralRadius += gridSize
            let angle = CGFloat(attempts) * 0.5
            position.x = point.x + spiralRadius * cos(angle)
            position.y = point.y + spiralRadius * sin(angle)
        }

        return position
    }

    private func iconName(for type: ComponentType) -> String {
        switch type {
        case .input: return "circle.fill"
        case .output: return "circle.fill"
        case .notGate: return "1.circle"
        default: return "square"
        }
    }

    private func color(for type: ComponentType) -> Color {
        switch type {
        case .input: return .blue
        case .output: return .red
        case .andGate: return .orange
        case .orGate: return .purple
        case .notGate: return .green
        }
    }

    // MARK: - Vista previa del circuito
    //
    // Antes esto asumía que el circuito siempre cabía en un rectángulo fijo de 600x300, y
    // encima escalaba X e Y por separado (lo que deformaba el dibujo). En cuanto la ecuación
    // tenía más variables o más términos, las compuertas quedaban fuera de esa caja o
    // aplastadas, y la vista previa se veía mal o directamente vacía. Ahora se calcula el
    // rectángulo real que ocupan las compuertas actuales y se escala manteniendo la proporción,
    // centrado dentro del espacio disponible — así que la vista previa se ve bien sin importar
    // cuántas variables o términos tenga el circuito.
    private var circuitMiniView: some View {
        VStack {
            Text("Vista Previa del Circuito")
                .font(.subheadline)

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))

                    ForEach(circuitComponents) { component in
                        ForEach(Array(component.connectedTo.enumerated()), id: \.offset) { index, connectedId in
                            if let connectedComponent = circuitComponents.first(where: { $0.id == connectedId }) {
                                ConnectionView(
                                    from: scalePosition(outputPin(of: connectedComponent), for: geometry.size),
                                    to: scalePosition(inputPin(of: component, at: index), for: geometry.size),
                                    isActive: connectedComponent.value
                                )
                            }
                        }
                    }

                    ForEach(circuitComponents) { component in
                        CircuitComponentView(
                            component: component,
                            isSelected: false,
                            onTap: {},
                            onDrag: { _ in },
                            onToggleValue: {},
                            onDelete: {}
                        )
                        .scaleEffect(previewScale(for: geometry.size))
                        .position(scalePosition(component.position, for: geometry.size))
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: 150)
        }
        .padding()
        .cardStyle()
    }

    // El rectángulo real que ocupan las compuertas se escala manteniendo la proporción para que
    // quepa en la vista previa (ver "scalePosition"), pero antes solo se reescalaban las
    // POSICIONES: cada compuerta se seguía dibujando a su tamaño real. En cuanto el circuito
    // tenía varias compuertas, sus posiciones quedaban comprimidas y cercanas entre sí, pero como
    // el tamaño no se achicaba junto con la posición, terminaban superpuestas unas sobre otras y
    // la vista previa se veía amontonada. "previewScale" calcula ese mismo factor de escala para
    // aplicarlo también al TAMAÑO de cada compuerta (con ".scaleEffect"), así que la vista previa
    // completa (posición y tamaño) se reduce de forma proporcional y nada queda encimado.
    private func previewScale(for size: CGSize) -> CGFloat {
        guard !circuitComponents.isEmpty else { return 1 }
        let xs = circuitComponents.map { $0.position.x }
        let ys = circuitComponents.map { $0.position.y }
        let minX = (xs.min() ?? 0) - 40
        let maxX = (xs.max() ?? 0) + 40
        let minY = (ys.min() ?? 0) - 40
        let maxY = (ys.max() ?? 0) + 40
        let contentWidth = max(maxX - minX, 1)
        let contentHeight = max(maxY - minY, 1)

        return min(size.width / contentWidth, size.height / contentHeight)
    }

    private func scalePosition(_ position: CGPoint, for size: CGSize) -> CGPoint {
        guard !circuitComponents.isEmpty else { return position }
        let xs = circuitComponents.map { $0.position.x }
        let ys = circuitComponents.map { $0.position.y }
        let minX = (xs.min() ?? 0) - 40
        let maxX = (xs.max() ?? 0) + 40
        let minY = (ys.min() ?? 0) - 40
        let maxY = (ys.max() ?? 0) + 40
        let contentWidth = max(maxX - minX, 1)
        let contentHeight = max(maxY - minY, 1)

        let scale = min(size.width / contentWidth, size.height / contentHeight)
        let offsetX = (size.width - contentWidth * scale) / 2
        let offsetY = (size.height - contentHeight * scale) / 2

        return CGPoint(
            x: (position.x - minX) * scale + offsetX,
            y: (position.y - minY) * scale + offsetY
        )
    }

    private var representationsSection: some View {
        VStack(spacing: 15) {
            Text("Representaciones")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            karnaughDisplay
            equationDisplay
        }
    }

    private var karnaughDisplay: some View {
        let n = variables.count
        let variableNames = variables.map { $0.name }

        return VStack {
            HStack {
                Text("Mapa de Karnaugh")
                    .font(.subheadline)
                Spacer()
                if n == 5 {
                    Text("\(variableNames[4]) = \(kmapLayer)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            kmapGrid(editable: false, cellSize: 40, headerSize: 20, n: n, variableNames: variableNames)
        }
        .cardStyle()
    }

    private var equationDisplay: some View {
        VStack {
            HStack {
                Text("Ecuación Booleana")
                    .font(.subheadline)
                Spacer()
            }

            Text(booleanEquation)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
        .cardStyle()
    }

    private var outputSection: some View {
        HStack {
            Text("Salida:")
                .font(.headline)

            Text(outputValue ? "1" : "0")
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .foregroundColor(outputValue ? .green : .red)
                .frame(width: 50, height: 50)
                .background(outputValue ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(outputValue ? Color.green : Color.red, lineWidth: 2)
                )
        }
        .padding()
        .cardStyle()
    }

    private func resetAll() {
        // Antes "Reiniciar" volvía a dejar 3 entradas (A, B, C) ya colocadas en el lienzo de
        // Circuito. Ahora deja exactamente el mismo estado vacío con el que arranca la app: sin
        // ninguna compuerta en el lienzo, y Karnaugh/Ecuación con sus 3 variables por defecto en
        // cero.
        circuitComponents.removeAll()
        variables = [
            Variable(name: "A", value: false),
            Variable(name: "B", value: false),
            Variable(name: "C", value: false)
        ]
        minterms = []
        booleanEquation = "f = "
        outputValue = false
        kmapLayer = 0
        scale = 1.0
        offset = .zero
        selectedComponent = nil
        connectionStart = nil
    }
}

// MARK: - Modifiers y Previews
struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding()
            .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        self.modifier(CardModifier())
    }
}

struct DigitalLogicView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Vista simplificada para preview
            DigitalLogicView()
                .previewDisplayName("Simplified")
                .environment(\.sizeCategory, .medium)

            // Otra variante
            DigitalLogicView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
        .previewLayout(.sizeThatFits)
    }
}
