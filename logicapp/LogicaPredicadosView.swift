import SwiftUI

// MARK: - Utilidades compartidas de análisis estructural de proposiciones
//
// Antes, varias partes de esta pantalla (el detector de tipo, la "Representación Formal"
// y "Teorema y Demostración") decidían la estructura de la proposición buscando texto de
// forma ingenua (por ejemplo, "¿el texto contiene ∧?" o "¿el texto contiene ¬?"), sin tomar
// en cuenta los paréntesis. Eso hacía que, por ejemplo, "(P→Q)∧R" se detectara como
// implicación en vez de conjunción (porque el → aparece en algún lugar del texto, aunque
// esté dentro de un paréntesis y no sea el operador principal). Estas funciones miran la
// profundidad de paréntesis para encontrar el operador que realmente manda en la proposición.

/// "[" y "]" agrupan exactamente igual que "(" y ")" (son solo otra forma de escribirlo, para
/// distinguir visualmente niveles de anidamiento). Se preserva el texto que la persona escribió
/// tal cual en el campo — nunca se le reemplaza un corchete por un paréntesis en pantalla — pero
/// para el análisis interno (nivel de anidamiento, operador principal, evaluación...) ambos se
/// tratan como el mismo símbolo de agrupación.
func normalizarCorchetes(_ expresion: String) -> String {
    expresion
        .replacingOccurrences(of: "[", with: "(")
        .replacingOccurrences(of: "]", with: ")")
}

/// Quita paréntesis externos que envuelven TODA la expresión, si sobran, repitiendo por si
/// hay varios niveles (p. ej. "((P∧Q))" -> "P∧Q").
func quitarParentesisRedundantes(_ expresion: String) -> String {
    var expr = normalizarCorchetes(expresion)
    while expr.hasPrefix("(") && expr.hasSuffix(")") {
        var profundidad = 0
        var envuelveTodo = true
        let caracteres = Array(expr)
        for (i, ch) in caracteres.enumerated() {
            if ch == "(" { profundidad += 1 }
            else if ch == ")" {
                profundidad -= 1
                if profundidad == 0 && i != caracteres.count - 1 {
                    envuelveTodo = false
                    break
                }
            }
        }
        if envuelveTodo && caracteres.count > 2 {
            expr = String(caracteres.dropFirst().dropLast())
        } else {
            break
        }
    }
    return expr
}

/// Indica si "operador" aparece al nivel superior (fuera de todo paréntesis) de "expresion".
func hayOperadorEnNivelSuperior(_ expresion: String, operador: Character) -> Bool {
    var profundidad = 0
    for ch in expresion {
        if ch == "(" { profundidad += 1 }
        else if ch == ")" { profundidad -= 1 }
        else if profundidad == 0 && ch == operador { return true }
    }
    return false
}

/// Divide "expresion" en los operandos separados por "operador" al nivel superior (fuera de
/// paréntesis). Por ejemplo, dividir "P∧(Q∨R)∧S" por "∧" da ["P", "(Q∨R)", "S"].
func dividirEnNivelSuperior(_ expresion: String, operador: Character) -> [String] {
    var partes: [String] = []
    var actual = ""
    var profundidad = 0
    for ch in expresion {
        if ch == "(" { profundidad += 1; actual.append(ch) }
        else if ch == ")" { profundidad -= 1; actual.append(ch) }
        else if profundidad == 0 && ch == operador {
            partes.append(actual)
            actual = ""
        } else {
            actual.append(ch)
        }
    }
    partes.append(actual)
    return partes
}

/// El conectivo que realmente manda en la proposición (el de menor precedencia presente al
/// nivel superior). Precedencia, de mayor a menor: ¬, ∧, ∨, ⊕, →, ↔.
enum ConectivoPrincipal {
    case variable, negacion, conjuncion, disyuncion, disyuncionExclusiva, implicacion, equivalencia
}

func conectivoPrincipal(_ expresionOriginal: String) -> ConectivoPrincipal {
    let expr = quitarParentesisRedundantes(expresionOriginal)
    guard !expr.isEmpty else { return .variable }

    if hayOperadorEnNivelSuperior(expr, operador: "↔") { return .equivalencia }
    if hayOperadorEnNivelSuperior(expr, operador: "→") { return .implicacion }
    if hayOperadorEnNivelSuperior(expr, operador: "⊕") { return .disyuncionExclusiva }
    if hayOperadorEnNivelSuperior(expr, operador: "∨") { return .disyuncion }
    if hayOperadorEnNivelSuperior(expr, operador: "∧") { return .conjuncion }
    if expr.hasPrefix("¬") { return .negacion }
    return .variable
}

/// Envuelve "expresion" entre paréntesis solo si es una expresión compuesta (para no negar o
/// agrupar de más una simple variable como "P").
func agruparSiEsCompuesta(_ expresion: String) -> String {
    conectivoPrincipal(expresion) == .variable ? expresion : "(\(expresion))"
}

/// Si "proposicion" es de la forma ¬(X) donde el paréntesis envuelve TODO lo que sigue al ¬,
/// regresa X ya sin esos paréntesis. Si el ¬ solo niega una variable suelta (sin paréntesis),
/// o el patrón no calza, regresa nil.
func interiorDeNegacionDeGrupo(_ proposicion: String) -> String? {
    let expr = normalizarCorchetes(proposicion.replacingOccurrences(of: " ", with: ""))
    guard expr.hasPrefix("¬") else { return nil }
    let resto = String(expr.dropFirst())
    guard resto.hasPrefix("("), resto.hasSuffix(")") else { return nil }
    let limpio = quitarParentesisRedundantes(resto)
    return limpio == resto ? nil : limpio
}

/// Separa una proposición en (antecedente, consecuente) usando el → de nivel superior (fuera
/// de paréntesis), sin importar si hay otras flechas anidadas dentro de sub-paréntesis.
func separarImplicacionPrincipal(_ proposicion: String) -> (antecedente: String, consecuente: String)? {
    let expr = quitarParentesisRedundantes(proposicion.replacingOccurrences(of: " ", with: ""))
    let partes = dividirEnNivelSuperior(expr, operador: "→")
    guard partes.count == 2 else { return nil }
    return (quitarParentesisRedundantes(partes[0]), quitarParentesisRedundantes(partes[1]))
}

/// Si la proposición calza con el patrón de la ley distributiva —A∧(B∨C) o A∨(B∧C), en
/// cualquier orden— regresa (A, B, C, operadorExterno). nil si no calza ese patrón.
func descomponerDistributiva(_ proposicion: String) -> (a: String, b: String, c: String, operadorExterno: Character)? {
    let expr = quitarParentesisRedundantes(proposicion.replacingOccurrences(of: " ", with: ""))
    let operadoresExternos: [Character] = ["∧", "∨"]
    for operadorExterno in operadoresExternos {
        guard hayOperadorEnNivelSuperior(expr, operador: operadorExterno) else { continue }
        let operandos = dividirEnNivelSuperior(expr, operador: operadorExterno)
        guard operandos.count == 2 else { continue }
        let operadorInterno: Character = operadorExterno == "∧" ? "∨" : "∧"

        for (compuestoIdx, atomicoIdx) in [(0, 1), (1, 0)] {
            let compuesto = quitarParentesisRedundantes(operandos[compuestoIdx])
            if compuesto != operandos[compuestoIdx],
               hayOperadorEnNivelSuperior(compuesto, operador: operadorInterno) {
                let subPartes = dividirEnNivelSuperior(compuesto, operador: operadorInterno)
                if subPartes.count == 2 {
                    return (operandos[atomicoIdx], subPartes[0], subPartes[1], operadorExterno)
                }
            }
        }
    }
    return nil
}

/// Si la proposición calza con el patrón ¬A∨B (la forma disyuntiva de una implicación,
/// A→B ≡ ¬A∨B), regresa (A, B). nil si no calza.
func descomponerImplicacionComoDisyuncion(_ proposicion: String) -> (a: String, b: String)? {
    let expr = quitarParentesisRedundantes(proposicion.replacingOccurrences(of: " ", with: ""))
    guard hayOperadorEnNivelSuperior(expr, operador: "∨") else { return nil }
    let operandos = dividirEnNivelSuperior(expr, operador: "∨")
    guard operandos.count == 2 else { return nil }

    if operandos[0].hasPrefix("¬") {
        return (String(operandos[0].dropFirst()), operandos[1])
    } else if operandos[1].hasPrefix("¬") {
        return (String(operandos[1].dropFirst()), operandos[0])
    }
    return nil
}

// MARK: - Motor de demostración paso a paso (Tautología / Contradicción)
//
// Antes, "Teorema y Demostración" solo mostraba dos líneas genéricas para cualquier tautología
// o contradicción ("Verdadera para todas las interpretaciones" / "Falsa para todas las
// interpretaciones"), sin importar qué proposición se haya escrito. Ahora, para ese caso, se
// arma una demostración algebraica real paso a paso: se eliminan las implicaciones/
// equivalencias (A→B ≡ ¬A∨B), se empujan las negaciones hacia adentro con De Morgan y doble
// negación, se aplanan los paréntesis redundantes por asociatividad, y luego se cancelan pares
// de literales complementarios (A∨¬A≡V, A∧¬A≡F) hasta reducir todo a un solo "V" o "F",
// exactamente como se demuestra a mano en el pizarrón.

/// Como agruparSiEsCompuesta, pero solo agrega paréntesis cuando la expresión es una
/// conjunción/disyunción/implicación/equivalencia (operador binario). Una negación como "¬P"
/// no necesita paréntesis para verse correctamente dentro de una lista unida por ∧/∨, así que
/// esta versión NO la envuelve (a diferencia de agruparSiEsCompuesta, que sí lo hace y que se
/// deja intacta porque otras partes ya aprobadas de la pantalla dependen de ese comportamiento).
func parentizarOperandoBinario(_ expresion: String) -> String {
    switch conectivoPrincipal(expresion) {
    case .conjuncion, .disyuncion, .disyuncionExclusiva, .implicacion, .equivalencia:
        return "(\(expresion))"
    default:
        return expresion
    }
}

/// Elimina recursivamente todas las implicaciones (A→B se convierte en ¬A∨B) y equivalencias
/// (A↔B se convierte en (¬A∨B)∧(¬B∨A)) de la expresión, dejando solo ¬, ∧ y ∨.
func eliminarImplicacionesRecursivo(_ expresion: String) -> String {
    let expr = quitarParentesisRedundantes(expresion.replacingOccurrences(of: " ", with: ""))
    guard !expr.isEmpty else { return expr }

    switch conectivoPrincipal(expr) {
    case .equivalencia:
        let partes = dividirEnNivelSuperior(expr, operador: "↔")
        guard partes.count == 2 else { return expr }
        let a = parentizarOperandoBinario(eliminarImplicacionesRecursivo(partes[0]))
        let b = parentizarOperandoBinario(eliminarImplicacionesRecursivo(partes[1]))
        return "(¬\(a)∨\(b))∧(¬\(b)∨\(a))"
    case .implicacion:
        let partes = dividirEnNivelSuperior(expr, operador: "→")
        guard partes.count == 2 else { return expr }
        let a = parentizarOperandoBinario(eliminarImplicacionesRecursivo(partes[0]))
        let b = parentizarOperandoBinario(eliminarImplicacionesRecursivo(partes[1]))
        return "¬\(a)∨\(b)"
    case .disyuncionExclusiva:
        // A⊕B ≡ (A∧¬B)∨(¬A∧B). Con más de dos operandos se pliega de izquierda a derecha
        // (A⊕B⊕C ≡ (A⊕B)⊕C), que es válido porque ⊕ es asociativo.
        let partes = dividirEnNivelSuperior(expr, operador: "⊕")
        guard partes.count >= 2 else { return expr }
        var acumulado = eliminarImplicacionesRecursivo(partes[0])
        for siguiente in partes.dropFirst() {
            let a = parentizarOperandoBinario(acumulado)
            let b = parentizarOperandoBinario(eliminarImplicacionesRecursivo(siguiente))
            acumulado = "(\(a)∧¬\(b))∨(¬\(a)∧\(b))"
        }
        return acumulado
    case .disyuncion:
        let partes = dividirEnNivelSuperior(expr, operador: "∨")
        return partes.map { parentizarOperandoBinario(eliminarImplicacionesRecursivo($0)) }.joined(separator: "∨")
    case .conjuncion:
        let partes = dividirEnNivelSuperior(expr, operador: "∧")
        return partes.map { parentizarOperandoBinario(eliminarImplicacionesRecursivo($0)) }.joined(separator: "∧")
    case .negacion:
        let interior = String(expr.dropFirst())
        return "¬\(parentizarOperandoBinario(eliminarImplicacionesRecursivo(interior)))"
    case .variable:
        return expr
    }
}

/// Empuja las negaciones hacia adentro usando las leyes de De Morgan (¬(A∧B)≡¬A∨¬B,
/// ¬(A∨B)≡¬A∧¬B) y elimina dobles negaciones (¬¬A≡A), hasta que toda negación quede pegada
/// directamente a una variable. Se debe llamar DESPUÉS de eliminarImplicacionesRecursivo, ya
/// que solo sabe empujar negaciones a través de ∧ y ∨.
func empujarNegacionesRecursivo(_ expresion: String) -> String {
    let expr = quitarParentesisRedundantes(expresion.replacingOccurrences(of: " ", with: ""))
    guard !expr.isEmpty else { return expr }

    switch conectivoPrincipal(expr) {
    case .disyuncion:
        let partes = dividirEnNivelSuperior(expr, operador: "∨")
        return partes.map { parentizarOperandoBinario(empujarNegacionesRecursivo($0)) }.joined(separator: "∨")
    case .conjuncion:
        let partes = dividirEnNivelSuperior(expr, operador: "∧")
        return partes.map { parentizarOperandoBinario(empujarNegacionesRecursivo($0)) }.joined(separator: "∧")
    case .negacion:
        let resto = String(expr.dropFirst())
        let restoLimpio = quitarParentesisRedundantes(resto)

        // Doble negación: ¬¬A -> A
        if conectivoPrincipal(restoLimpio) == .negacion, restoLimpio.hasPrefix("¬") {
            return empujarNegacionesRecursivo(String(restoLimpio.dropFirst()))
        }

        switch conectivoPrincipal(restoLimpio) {
        case .conjuncion:
            let partes = dividirEnNivelSuperior(restoLimpio, operador: "∧")
            let negadas = partes.map { empujarNegacionesRecursivo("¬\(parentizarOperandoBinario($0))") }
            return negadas.map(parentizarOperandoBinario).joined(separator: "∨")
        case .disyuncion:
            let partes = dividirEnNivelSuperior(restoLimpio, operador: "∨")
            let negadas = partes.map { empujarNegacionesRecursivo("¬\(parentizarOperandoBinario($0))") }
            return negadas.map(parentizarOperandoBinario).joined(separator: "∧")
        default:
            // Variable suelta (o algo que no debería llegar aquí si ya se llamó antes a
            // eliminarImplicacionesRecursivo): se deja como negación simple.
            return "¬\(restoLimpio)"
        }
    default:
        return expr
    }
}

/// Divide "expresion" por "operador" y aplana recursivamente los paréntesis que agrupan ese
/// mismo operador (asociatividad): p. ej. "(¬P∨Q)∨(¬Q∨P)" -> ["¬P","Q","¬Q","P"].
func aplanarMismoOperador(_ expresion: String, operador: Character) -> [String] {
    let partes = dividirEnNivelSuperior(expresion, operador: operador)
    var resultado: [String] = []
    for parte in partes {
        let limpio = quitarParentesisRedundantes(parte)
        if hayOperadorEnNivelSuperior(limpio, operador: operador) {
            resultado.append(contentsOf: aplanarMismoOperador(limpio, operador: operador))
        } else {
            resultado.append(limpio)
        }
    }
    return resultado
}

/// Aplana recursivamente toda la expresión: quita, en cualquier nivel de anidamiento, los
/// paréntesis que agrupan el mismo operador que ya los envuelve.
func aplanarTodoRecursivo(_ expresion: String) -> String {
    let expr = quitarParentesisRedundantes(expresion.replacingOccurrences(of: " ", with: ""))
    guard !expr.isEmpty else { return expr }

    switch conectivoPrincipal(expr) {
    case .disyuncion:
        let planos = aplanarMismoOperador(expr, operador: "∨")
        return planos.map { parentizarOperandoBinario(aplanarTodoRecursivo($0)) }.joined(separator: "∨")
    case .conjuncion:
        let planos = aplanarMismoOperador(expr, operador: "∧")
        return planos.map { parentizarOperandoBinario(aplanarTodoRecursivo($0)) }.joined(separator: "∧")
    case .negacion:
        let interior = String(expr.dropFirst())
        return "¬\(parentizarOperandoBinario(aplanarTodoRecursivo(interior)))"
    default:
        return expr
    }
}

/// Indica si dos literales/expresiones son complementarios: uno es la negación exacta del otro
/// (p. ej. "P" y "¬P", o "(A∧B)" y "¬(A∧B)").
func sonComplementarios(_ a: String, _ b: String) -> Bool {
    if a == "¬\(b)" { return true }
    if b == "¬\(a)" { return true }
    return false
}

/// Busca, entre los operandos de nivel superior de "expresion" (separados por su conectivo
/// principal, ∧ o ∨), dos que sean complementarios y los sustituye por una sola constante: "V"
/// si el operador es ∨ (Tercero Excluido: A∨¬A≡V), o "F" si es ∧ (Ley de Contradicción:
/// A∧¬A≡F). Regresa (nuevaExpresion, nombreDeLaRegla), o nil si no hay ningún par así en este
/// nivel.
func sustituirComplementariosNivelSuperior(_ expresion: String) -> (String, String)? {
    let expr = quitarParentesisRedundantes(expresion.replacingOccurrences(of: " ", with: ""))
    let conectivo = conectivoPrincipal(expr)
    guard conectivo == .conjuncion || conectivo == .disyuncion else { return nil }

    let operador: Character = conectivo == .conjuncion ? "∧" : "∨"
    let operandos = dividirEnNivelSuperior(expr, operador: operador)
    guard operandos.count > 1 else { return nil }

    for i in 0..<operandos.count {
        for j in (i + 1)..<operandos.count {
            if sonComplementarios(operandos[i], operandos[j]) {
                let valorConstante = conectivo == .disyuncion ? "V" : "F"
                var restantes = operandos
                restantes.remove(at: j)
                restantes.remove(at: i)
                restantes.append(valorConstante)
                let regla = conectivo == .disyuncion
                    ? "Tercero Excluido (A∨¬A≡V)"
                    : "Ley de Contradicción (A∧¬A≡F)"
                return (restantes.joined(separator: String(operador)), regla)
            }
        }
    }
    return nil
}

/// Una vez que ya aparecen constantes "V"/"F" mezcladas con el resto de la expresión, las
/// combina un paso a la vez usando dominación (V∨X≡V, F∧X≡F), identidad (F∨X≡X, V∧X≡X) e
/// idempotencia (V∨V≡V, F∧F≡F), hasta reducir todo a un solo "V" o "F". Regresa
/// (nuevaExpresion, nombreDeLaRegla), o nil si ya no hay ninguna constante que combinar.
func absorberDominanteNivelSuperior(_ expresion: String) -> (String, String)? {
    let expr = quitarParentesisRedundantes(expresion.replacingOccurrences(of: " ", with: ""))
    guard expr != "V" && expr != "F" else { return nil }

    let conectivo = conectivoPrincipal(expr)
    guard conectivo == .conjuncion || conectivo == .disyuncion else { return nil }

    if conectivo == .disyuncion {
        let operandos = dividirEnNivelSuperior(expr, operador: "∨")
        guard operandos.count > 1 else { return nil }
        if operandos.allSatisfy({ $0 == "V" }) { return ("V", "Idempotencia (V∨V≡V)") }
        if operandos.contains("V") { return ("V", "Dominación (V∨X≡V)") }
        if operandos.contains("F") {
            let restantes = operandos.filter { $0 != "F" }
            return (restantes.isEmpty ? "F" : restantes.joined(separator: "∨"), "Identidad (F∨X≡X)")
        }
        return nil
    } else {
        let operandos = dividirEnNivelSuperior(expr, operador: "∧")
        guard operandos.count > 1 else { return nil }
        if operandos.allSatisfy({ $0 == "F" }) { return ("F", "Idempotencia (F∧F≡F)") }
        if operandos.contains("F") { return ("F", "Dominación (F∧X≡F)") }
        if operandos.contains("V") {
            let restantes = operandos.filter { $0 != "V" }
            return (restantes.isEmpty ? "V" : restantes.joined(separator: "∧"), "Identidad (V∧X≡X)")
        }
        return nil
    }
}

// MARK: - Evaluador compartido de proposiciones
//
// Antes había DOS copias casi idénticas de este evaluador (una en LogicaProposicionalView
// para decidir si es tautología/contradicción, y otra dentro de EnhancedTruthTableView para
// pintar la tabla). Al ser copias independientes podían llegar a dar resultados distintos
// para el mismo texto. Ahora ambas usan esta única versión (la más completa de las dos, que
// sabe negar tanto un dígito como un grupo entre paréntesis).

/// Evalúa una proposición (con variables ya conocidas) a verdadero/falso.
func evaluarProposicionCompartida(_ expresion: String, con valores: [String: Bool]) -> Bool {
    var expr = normalizarCorchetes(expresion.replacingOccurrences(of: " ", with: ""))

    for (variable, valor) in valores {
        expr = expr.replacingOccurrences(of: variable, with: valor ? "1" : "0")
    }

    func evaluarExpresionSimple(_ expresionEntrada: String) -> String {
        var exp = expresionEntrada

        // Negaciones primero: de un dígito, o de un grupo completo entre paréntesis.
        while let range = exp.range(of: "¬[01()]|¬[∧∨→↔⊕]", options: .regularExpression) {
            let nextChar = exp[exp.index(range.lowerBound, offsetBy: 1)]
            let negatedValue: String
            if nextChar == "1" {
                negatedValue = "0"
            } else if nextChar == "0" {
                negatedValue = "1"
            } else if nextChar == "(" {
                var balance = 1
                var endIndex = exp.index(range.lowerBound, offsetBy: 2)
                while balance != 0 && endIndex < exp.endIndex {
                    if exp[endIndex] == "(" {
                        balance += 1
                    } else if exp[endIndex] == ")" {
                        balance -= 1
                    }
                    endIndex = exp.index(endIndex, offsetBy: 1)
                }
                let subExpr = String(exp[exp.index(range.lowerBound, offsetBy: 1)..<endIndex])
                let evaluated = evaluarExpresionSimple(subExpr)
                negatedValue = evaluated == "1" ? "0" : "1"
                exp.replaceSubrange(range.lowerBound..<endIndex, with: negatedValue)
                continue
            } else {
                negatedValue = "0"
            }
            exp.replaceSubrange(range, with: negatedValue)
        }

        while let rango = exp.range(of: #"\([01∧∨→↔⊕¬]+\)"#, options: .regularExpression) {
            let subExpr = String(exp[exp.index(rango.lowerBound, offsetBy: 1)..<exp.index(rango.upperBound, offsetBy: -1)])
            let resultado = evaluarExpresionSimple(subExpr)
            exp.replaceSubrange(rango, with: resultado)
        }

        while let rango = exp.range(of: #"[01]∧[01]"#, options: .regularExpression) {
            let partes = Array(exp[rango])
            let izquierda = partes[0] == "1"
            let derecha = partes[2] == "1"
            exp.replaceSubrange(rango, with: (izquierda && derecha) ? "1" : "0")
        }

        while let rango = exp.range(of: #"[01]∨[01]"#, options: .regularExpression) {
            let partes = Array(exp[rango])
            let izquierda = partes[0] == "1"
            let derecha = partes[2] == "1"
            exp.replaceSubrange(rango, with: (izquierda || derecha) ? "1" : "0")
        }

        // ⊕ (disyunción exclusiva): verdadera solo cuando los dos valores son distintos.
        while let rango = exp.range(of: #"[01]⊕[01]"#, options: .regularExpression) {
            let partes = Array(exp[rango])
            let izquierda = partes[0] == "1"
            let derecha = partes[2] == "1"
            exp.replaceSubrange(rango, with: (izquierda != derecha) ? "1" : "0")
        }

        while let rango = exp.range(of: #"[01]→[01]"#, options: .regularExpression) {
            let partes = Array(exp[rango])
            let antecedente = partes[0] == "1"
            let consecuente = partes[2] == "1"
            exp.replaceSubrange(rango, with: (!antecedente || consecuente) ? "1" : "0")
        }

        while let rango = exp.range(of: #"[01]↔[01]"#, options: .regularExpression) {
            let partes = Array(exp[rango])
            let izquierda = partes[0] == "1"
            let derecha = partes[2] == "1"
            exp.replaceSubrange(rango, with: (izquierda == derecha) ? "1" : "0")
        }

        return exp
    }

    while let rango = encontrarParentesisMasInternosCompartido(expr) {
        let subExpr = String(expr[expr.index(rango.lowerBound, offsetBy: 1)..<expr.index(rango.upperBound, offsetBy: -1)])
        let resultado = evaluarExpresionSimple(subExpr)
        expr.replaceSubrange(rango, with: resultado)
    }

    let resultadoFinal = evaluarExpresionSimple(expr)
    return resultadoFinal == "1"
}

func encontrarParentesisMasInternosCompartido(_ expresion: String) -> Range<String.Index>? {
    var stack = [String.Index]()
    var resultado: Range<String.Index>?

    for index in expresion.indices {
        let char = expresion[index]
        if char == "(" {
            stack.append(index)
        } else if char == ")" {
            if let start = stack.popLast() {
                let contenido = expresion[expresion.index(after: start)..<index]
                if !contenido.contains("(") {
                    resultado = start..<expresion.index(after: index)
                    break
                }
            }
        }
    }
    return resultado
}

func extraerVariablesCompartido(_ proposicion: String) -> [String] {
    Set(proposicion.filter { $0.isLetter && $0.isUppercase }.map { String($0) }).sorted()
}

struct LogicaProposicionalView: View {
    @State private var proposicion: String = "(P ∧ Q) → R"
    @State private var resultado: String = "Ingrese una proposición"
    @State private var tipoProposicion: String = ""
    @State private var mostrarHistorial = false
    @State private var mostrarSimbolos = false
    @State private var historial: [String] = []
    
    // "T" es una quinta variable proposicional más, exactamente igual que P, Q, R y S (no una
    // constante): "extraerVariablesCompartido" ya la reconoce sola, por ser una letra mayúscula
    // más, así que entra directo a la tabla de verdad con su propia columna V/F. "[" y "]" son
    // solo otra forma de escribir agrupación, igual que "(" y ")" — en el campo de texto se
    // conservan tal cual la persona los escribió (nunca se muestran como paréntesis en pantalla);
    // es únicamente a nivel interno, dentro de "normalizarCorchetes" (usada por
    // "quitarParentesisRedundantes", "interiorDeNegacionDeGrupo" y "evaluarProposicionCompartida"),
    // donde se tratan como el mismo símbolo que "(" y ")" para el análisis.
    let simbolos = ["∧", "∨", "⊕", "→", "↔", "¬", "(", ")", "[", "]", "P", "Q", "R", "S", "T"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Button(action: { mostrarHistorial.toggle() }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title2)
                        }
                        
                        Spacer()
                        
                        Text("Lógica Proposicional")
                            .font(.title2)
                            .bold()
                        
                        Spacer()
                        
                        Button(action: { mostrarSimbolos.toggle() }) {
                            Image(systemName: "function")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Input field
                    TextField("Ej: (P ∧ Q) → R", text: $proposicion)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onChange(of: proposicion) { _ in analizarProposicion() }

                    // Symbol keyboard
                    if mostrarSimbolos {
                        symbolKeyboard
                    }

                    // Results
                    if !tipoProposicion.isEmpty {
                        resultadoView
                    }

                    // Buttons
                    HStack(spacing: 15) {
                        Button("Limpiar", action: borrarCampos)
                            .buttonStyle(ActionButtonStyle(color: .red))
                    }
                    .padding(.horizontal)

                    // Visualizations
                    visualizationsSection
                }
                .padding(.vertical)
            }
            .sheet(isPresented: $mostrarHistorial) {
                HistorialView(historial: $historial, mostrarHistorial: $mostrarHistorial)
            }
            .navigationTitle("Lógica Proposicional")
            .animation(.easeInOut, value: mostrarSimbolos)
        }
        .onAppear(perform: analizarProposicion)
    }
    
    // MARK: - Subviews
    private var symbolKeyboard: some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
        return LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(simbolos, id: \.self) { simbolo in
                Button(action: {
                    proposicion += simbolo
                    analizarProposicion()
                }) {
                    Text(simbolo)
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
    
    private var resultadoView: some View {
        Text(tipoProposicionFormateada())
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                tipoProposicion.contains("Tautología") ? Color.green.opacity(0.2) :
                tipoProposicion.contains("Contradicción") ? Color.red.opacity(0.2) :
                Color.blue.opacity(0.2)
            )
            .cornerRadius(10)
            .padding(.horizontal)
    }
    
    private var visualizationsSection: some View {
        VStack(spacing: 30) {
            EnhancedTruthTableView(proposicion: proposicion, tipoProposicion: tipoProposicion)
                .frame(minHeight: 100, maxHeight: 400)
            
            EcuacionView(proposicion: proposicion, tipoProposicion: tipoProposicion)
                .frame(height: 80)
            
            TeoremaView(proposicion: proposicion, tipoProposicion: tipoProposicion)
                .frame(minHeight: 150)
        }
        .padding()
    }

    // MARK: - Logic Functions
    private func analizarProposicion() {
        guard !proposicion.isEmpty else {
            resultado = "Ingrese una proposición"
            tipoProposicion = ""
            return
        }
        
        let (esTautologia, esContradiccion) = verificarTautologiaContradiccion(proposicion)
        
        if esTautologia {
            tipoProposicion = "Tautología"
            resultado = "La proposición es siempre verdadera (V)"
        } else if esContradiccion {
            tipoProposicion = "Contradicción"
            resultado = "La proposición es siempre falsa (F)"
        } else {
            tipoProposicion = detectarTipoProposicion(proposicion)
            resultado = "Análisis: \(proposicion)\n\(explicacionTipoProposicion(tipoProposicion))"
        }
        
        guard !proposicion.isEmpty else { return }
        let entrada = "\(proposicion) → \(tipoProposicion)"
        if !historial.contains(entrada) {
            historial.append(entrada)
        }
    }
    
    // Antes esta función decidía el tipo solo con "¿el texto contiene tal símbolo?", sin ver
    // paréntesis ni precedencia. Eso causaba dos problemas concretos: (1) revisaba ∧ antes que
    // ∨ sin importar cuál era realmente el operador principal, así que algo como "(P→Q)∨R"
    // podía salir mal clasificado; y (2) la condición de "múltiple" (expr.components(...)
    // .count > 1) es cierta SIEMPRE que el símbolo aparece al menos una vez, así que una
    // conjunción o disyunción simple de 2 términos jamás mostraba "Conjunción"/"Disyunción",
    // siempre decía "Múltiple". Ahora se usa el operador de nivel superior (fuera de
    // paréntesis) para decidir, y se cuentan los operandos reales para "simple" vs "múltiple".
    private func detectarTipoProposicion(_ proposicion: String) -> String {
        let expr = quitarParentesisRedundantes(proposicion.replacingOccurrences(of: " ", with: ""))
        guard !expr.isEmpty else { return "Proposición Compuesta" }

        switch conectivoPrincipal(expr) {
        case .equivalencia:
            return "Equivalencia Lógica"

        case .implicacion:
            guard let partes = separarImplicacionPrincipal(expr) else { return "Implicación Simple" }
            let esCompuesta = conectivoPrincipal(partes.antecedente) != .variable ||
                               conectivoPrincipal(partes.consecuente) != .variable
            return esCompuesta ? "Implicación Compuesta" : "Implicación Simple"

        case .disyuncionExclusiva:
            let operandos = dividirEnNivelSuperior(expr, operador: "⊕")
            return operandos.count > 2 ? "Disyunción Exclusiva Múltiple" : "Disyunción Exclusiva"

        case .disyuncion:
            let operandos = dividirEnNivelSuperior(expr, operador: "∨")
            if operandos.count == 2 {
                if descomponerDistributiva(expr) != nil { return "Ley Distributiva" }
                if descomponerImplicacionComoDisyuncion(expr) != nil { return "Implicación como Disyunción" }
            }
            return operandos.count > 2 ? "Disyunción Múltiple" : "Disyunción"

        case .conjuncion:
            let operandos = dividirEnNivelSuperior(expr, operador: "∧")
            if operandos.count == 2, descomponerDistributiva(expr) != nil {
                return "Ley Distributiva"
            }
            return operandos.count > 2 ? "Conjunción Múltiple" : "Conjunción"

        case .negacion:
            let interior = String(expr.dropFirst())
            if interior.hasPrefix("¬") {
                return "Doble Negación"
            }
            if let grupo = interiorDeNegacionDeGrupo(expr) {
                switch conectivoPrincipal(grupo) {
                case .conjuncion: return "Ley de De Morgan (Conjunción)"
                case .disyuncion: return "Ley de De Morgan (Disyunción)"
                case .variable where grupo.count == 1: return "Negación Simple"
                default: return "Negación Compuesta"
                }
            }
            return interior.count == 1 ? "Negación Simple" : "Negación Compuesta"

        case .variable:
            return expr.count == 1 && expr.first?.isLetter == true ? "Variable Proposicional" : "Proposición Compuesta"
        }
    }
    
    // NOTA: el evaluador de expresiones (evaluarProposicion / encontrarParentesisMasInternos)
    // y extraerVariables vivían duplicados aquí y otra vez dentro de EnhancedTruthTableView.
    // Al ser dos copias independientes, era posible que el análisis de tautología/contradicción
    // y la tabla de verdad llegaran a resultados distintos para la misma proposición. Ahora
    // ambas partes usan las funciones compartidas del principio del archivo
    // (evaluarProposicionCompartida / extraerVariablesCompartido), así siempre concuerdan.
    private func verificarTautologiaContradiccion(_ proposicion: String) -> (Bool, Bool) {
        let variables = extraerVariablesCompartido(proposicion)
        guard !variables.isEmpty else { return (false, false) }

        let combinaciones = generarCombinaciones(variables.count)
        var todosVerdaderos = true
        var todosFalsos = true

        for combinacion in combinaciones {
            let valores = Dictionary(uniqueKeysWithValues: zip(variables, combinacion))
            let resultado = evaluarProposicionCompartida(proposicion, con: valores)

            if !resultado { todosVerdaderos = false }
            if resultado { todosFalsos = false }

            if !todosVerdaderos && !todosFalsos { break }
        }

        return (todosVerdaderos, todosFalsos)
    }

    private func generarCombinaciones(_ count: Int) -> [[Bool]] {
        guard count > 0 else { return [] }
        return (0..<(1 << count)).map { i in
            (0..<count).map { (i & (1 << $0)) != 0 }
        }
    }

    private func tipoProposicionFormateada() -> String {
        if tipoProposicion.contains("Tautología") { return "🔍 Es una Tautología (siempre V)" }
        if tipoProposicion.contains("Contradicción") { return "🔍 Es una Contradicción (siempre F)" }
        return "🔍 \(tipoProposicion)"
    }
    
    private func explicacionTipoProposicion(_ tipo: String) -> String {
        switch tipo {
        case "Implicación Simple", "Implicación Compuesta":
            return "Falsa solo cuando antecedente es verdadero y consecuente es falso"
        case "Conjunción": return "Verdadera solo cuando ambos operandos son verdaderos"
        case "Conjunción Múltiple": return "Verdadera solo cuando todas las partes son verdaderas"
        case "Disyunción": return "Falsa solo cuando ambos operandos son falsos"
        case "Disyunción Múltiple": return "Falsa solo cuando todas las partes son falsas"
        case "Disyunción Exclusiva": return "Verdadera solo cuando los dos operandos tienen valores diferentes"
        case "Disyunción Exclusiva Múltiple": return "Verdadera cuando un número impar de partes son verdaderas"
        case "Equivalencia Lógica": return "Verdadera cuando ambos operandos tienen el mismo valor"
        case "Negación Simple": return "Invierte el valor (verdadero→falso, falso→verdadero)"
        case "Negación Compuesta": return "Niega una expresión compuesta"
        case "Ley de De Morgan (Conjunción)": return "¬(A ∧ B) ↔ (¬A ∨ ¬B)"
        case "Ley de De Morgan (Disyunción)": return "¬(A ∨ B) ↔ (¬A ∧ ¬B)"
        case "Ley Distributiva": return "A ∧ (B ∨ C) ↔ (A ∧ B) ∨ (A ∧ C) o A ∨ (B ∧ C) ↔ (A ∨ B) ∧ (A ∨ C)"
        case "Doble Negación": return "¬¬A ↔ A"
        case "Implicación como Disyunción": return "A → B ↔ ¬A ∨ B"
        case "Variable Proposicional": return "Variable atómica (P, Q, R...)"
        default: return "Proposición lógica compuesta"
        }
    }
    
    private func borrarCampos() {
        withAnimation {
            proposicion = ""
            resultado = "Ingrese una proposición"
            tipoProposicion = ""
        }
    }
}

struct EnhancedTruthTableView: View {
    let proposicion: String
    let tipoProposicion: String
    
    // variables/combinaciones y el evaluador ahora usan las versiones compartidas del
    // principio del archivo (ver nota en LogicaProposicionalView) para que la tabla nunca
    // pueda dar un resultado distinto al que anuncia "tipo de proposición".
    private var variables: [String] {
        extraerVariablesCompartido(proposicion)
    }

    private var combinaciones: [[Bool]] {
        let count = variables.count
        guard count > 0 else { return [] }
        // Orden convencional de tabla de verdad: la primera variable (alfabéticamente) empieza
        // en V y es la que cambia más despacio (las primeras mitad de filas en V, la otra mitad
        // en F), y la última variable empieza en V y cambia en cada fila — igual que en
        // cualquier libro de texto. Antes el orden era al revés (la primera variable cambiaba
        // más rápido que la última), lo que daba las mismas 32 combinaciones pero en un orden
        // de filas distinto al convencional.
        return (0..<(1 << count)).map { i in
            (0..<count).map { (i & (1 << (count - 1 - $0))) == 0 }
        }
    }

    var body: some View {
        VStack {
            Text("Tabla de Verdad")
                .font(.headline)
                .padding(.bottom, 5)
            
            if variables.isEmpty {
                Text("Ingrese una proposición válida")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Encabezados
                        HStack(spacing: 0) {
                            ForEach(variables, id: \.self) { variable in
                                Text(variable)
                                    .frame(width: 40, height: 40)
                                    .padding(.horizontal, 4)
                                    .background(Color.blue.opacity(0.7))
                                    .foregroundColor(.white)
                                    .border(Color.white, width: 1)
                                    .fixedSize()
                            }
                            
                            Text(proposicion)
                                .frame(minWidth: CGFloat(max(150, proposicion.count * 10)), minHeight: 40)
                                .padding(.horizontal, 4)
                                .background(Color.blue.opacity(0.7))
                                .foregroundColor(.white)
                                .border(Color.white, width: 1)
                        }
                        
                        // Filas
                        ForEach(0..<combinaciones.count, id: \.self) { i in
                            HStack(spacing: 0) {
                                let valores = Dictionary(uniqueKeysWithValues: zip(variables, combinaciones[i]))
                                
                                ForEach(variables, id: \.self) { variable in
                                    Text(valores[variable]! ? "V" : "F")
                                        .frame(width: 40, height: 40)
                                        .padding(.horizontal, 4)
                                        .background(i % 2 == 0 ? Color.gray.opacity(0.1) : Color.gray.opacity(0.2))
                                        .border(Color.white, width: 1)
                                        .fixedSize()
                                }

                                let valorFinal = evaluarProposicionCompartida(proposicion, con: valores)
                                Text(valorFinal ? "V" : "F")
                                    .frame(minWidth: CGFloat(max(150, proposicion.count * 10)), minHeight: 40)
                                    .padding(.horizontal, 4)
                                    .background(
                                        i % 2 == 0 ? Color.gray.opacity(0.1) : Color.gray.opacity(0.2)
                                    )
                                    .border(Color.white, width: 1)
                                    .fontWeight(.bold)
                                    .foregroundColor(
                                        tipoProposicion.contains("Tautología") ? .green :
                                        tipoProposicion.contains("Contradicción") ? .red :
                                        .primary
                                    )
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct EcuacionView: View {
    let proposicion: String
    let tipoProposicion: String
    
    var body: some View {
        VStack {
            Text("Representación Formal")
                .font(.headline)
            
            Text(ecuacionFormateada())
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    tipoProposicion.contains("Tautología") ? Color.green.opacity(0.1) :
                    tipoProposicion.contains("Contradicción") ? Color.red.opacity(0.1) :
                    Color.blue.opacity(0.1)
                )
                .cornerRadius(10)
        }
    }
    
    // Antes esta función partía el texto buscando literalmente " ∧ " o " ∨ " CON espacios
    // alrededor, pero el teclado de símbolos de esta pantalla escribe "∧"/"∨" sin espacios
    // — así que la división nunca encontraba nada y `partes[1]` podía tronar la app
    // (index out of range) apenas se detectara una Ley de De Morgan. Ahora se usa el mismo
    // análisis por niveles de paréntesis que el resto de la pantalla, y ya no depende de que
    // el texto tenga espacios en un lugar exacto.
    private func ecuacionFormateada() -> String {
        if tipoProposicion.contains("Tautología") {
            return "⊨ \(proposicion) (Tautología)"
        } else if tipoProposicion.contains("Contradicción") {
            return "⊨ ¬(\(proposicion)) (Contradicción)"
        } else if tipoProposicion.contains("Ley de De Morgan") {
            if let grupo = interiorDeNegacionDeGrupo(proposicion) {
                let operadorInterno: Character = tipoProposicion.contains("Disyunción") ? "∨" : "∧"
                let partes = dividirEnNivelSuperior(grupo, operador: operadorInterno).map(quitarParentesisRedundantes)
                if partes.count == 2 {
                    let operadorContrario: Character = operadorInterno == "∧" ? "∨" : "∧"
                    return "¬(\(partes[0])\(operadorInterno)\(partes[1])) ≡ (¬\(partes[0])\(operadorContrario)¬\(partes[1]))"
                }
            }
        } else if tipoProposicion == "Ley Distributiva" {
            if let (a, b, c, opExt) = descomponerDistributiva(proposicion) {
                let opInt: Character = opExt == "∧" ? "∨" : "∧"
                return "\(a)\(opExt)(\(b)\(opInt)\(c)) ≡ (\(a)\(opExt)\(b))\(opInt)(\(a)\(opExt)\(c))"
            }
        } else if tipoProposicion == "Implicación como Disyunción" {
            if let (a, b) = descomponerImplicacionComoDisyuncion(proposicion) {
                return "\(proposicion) ≡ \(agruparSiEsCompuesta(a))→\(b)"
            }
        } else if tipoProposicion.contains("Implicación") {
            if let partes = separarImplicacionPrincipal(proposicion) {
                return "\(proposicion) ≡ ¬\(agruparSiEsCompuesta(partes.antecedente)) ∨ \(agruparSiEsCompuesta(partes.consecuente))"
            }
        } else if tipoProposicion.contains("Doble Negación") {
            let sinEspacios = proposicion.replacingOccurrences(of: " ", with: "")
            let variable = String(sinEspacios.dropFirst(2))
            return "¬¬\(variable) ≡ \(variable)"
        } else if tipoProposicion.contains("Disyunción Exclusiva") {
            let expr = quitarParentesisRedundantes(proposicion.replacingOccurrences(of: " ", with: ""))
            let operandos = dividirEnNivelSuperior(expr, operador: "⊕").map(quitarParentesisRedundantes)
            if operandos.count == 2 {
                let a = operandos[0], b = operandos[1]
                return "\(a)⊕\(b) ≡ (\(a)∧¬\(b))∨(¬\(a)∧\(b))"
            }
        }
        return proposicion
    }
}

struct TeoremaView: View {
    let proposicion: String
    let tipoProposicion: String
    
    private struct PasoDemostracion: Identifiable {
        let id = UUID()
        let expresion: String
        let regla: String
    }
    
    // Antes, cuando la proposición NO era tautología/contradicción/implicación/doble
    // negación/De Morgan, la demostración decidía qué mostrar viendo si el texto "contiene"
    // ∧, luego ∨, luego ¬ — SIEMPRE en ese orden, sin ver paréntesis. Por eso algo como
    // "¬(P∧Q)" (una negación) terminaba mostrando el paso de conjunción ("Verdadera solo si
    // ambos son verdaderos"), que es literalmente la explicación contraria a lo que dice la
    // proposición. Además, separarProposicion/separarImplicacion partían el texto con
    // components(separatedBy:), que no distingue paréntesis y podía romper la explicación en
    // pedazos sin sentido. Ahora los pasos se arman a partir de tipoProposicion (que ya viene
    // bien calculado) y de los mismos ayudantes por niveles de paréntesis del resto de la
    // pantalla, así el paso a paso siempre concuerda con el tipo anunciado arriba.
    private func generarDemostracion() -> [PasoDemostracion] {
        var pasos: [PasoDemostracion] = []
        let proposicionLimpia = quitarParentesisRedundantes(proposicion.replacingOccurrences(of: " ", with: ""))

        if tipoProposicion.contains("Tautología") || tipoProposicion.contains("Contradicción") {
            // Demostración algebraica real, paso a paso, en vez del mensaje genérico de antes:
            // se eliminan implicaciones/equivalencias, se empujan las negaciones con De Morgan
            // y doble negación, se aplana por asociatividad, y se cancelan literales
            // complementarios (A∨¬A≡V, A∧¬A≡F) hasta llegar a un solo "V" o "F".
            var actual = proposicionLimpia
            pasos.append(PasoDemostracion(expresion: actual, regla: "Original"))

            func agregarPasoSiCambio(_ nuevo: String, regla: String) {
                let nuevoLimpio = quitarParentesisRedundantes(nuevo)
                if nuevoLimpio != actual {
                    actual = nuevoLimpio
                    pasos.append(PasoDemostracion(expresion: actual, regla: regla))
                }
            }

            agregarPasoSiCambio(eliminarImplicacionesRecursivo(actual), regla: "Equivalencia de Implicación/Bicondicional")
            agregarPasoSiCambio(empujarNegacionesRecursivo(actual), regla: "Ley de De Morgan / Doble Negación")
            agregarPasoSiCambio(aplanarTodoRecursivo(actual), regla: "Ley Asociativa/Conmutativa")

            var iteraciones = 0
            while iteraciones < 12, let (nuevaExpresion, regla) = sustituirComplementariosNivelSuperior(actual) {
                agregarPasoSiCambio(nuevaExpresion, regla: regla)
                iteraciones += 1
            }

            iteraciones = 0
            while iteraciones < 12, let (nuevaExpresion, regla) = absorberDominanteNivelSuperior(actual) {
                agregarPasoSiCambio(nuevaExpresion, regla: regla)
                iteraciones += 1
            }

            // Último recurso: si alguna combinación no cubierta arriba no terminó de reducirse
            // a "V"/"F" (proposicion con estructura poco común), se agrega el resultado final
            // (ya confirmado por la tabla de verdad al calcular tipoProposicion) para que la
            // demostración nunca se quede a medias.
            if actual != "V" && actual != "F" {
                pasos.append(PasoDemostracion(expresion: tipoProposicion.contains("Tautología") ? "V" : "F",
                                               regla: "Verificado por tabla de verdad"))
            }

        } else if tipoProposicion.contains("Ley de De Morgan"), let grupo = interiorDeNegacionDeGrupo(proposicionLimpia) {
            let operadorInterno: Character = tipoProposicion.contains("Disyunción") ? "∨" : "∧"
            let partes = dividirEnNivelSuperior(grupo, operador: operadorInterno).map(quitarParentesisRedundantes)
            if partes.count == 2 {
                let operadorContrario: Character = operadorInterno == "∧" ? "∨" : "∧"
                pasos.append(PasoDemostracion(expresion: "¬(\(partes[0])\(operadorInterno)\(partes[1]))", regla: "Original"))
                pasos.append(PasoDemostracion(expresion: "¬\(partes[0]) \(operadorContrario) ¬\(partes[1])",
                                               regla: operadorInterno == "∧" ? "De Morgan (Conjunción)" : "De Morgan (Disyunción)"))
            }

        } else if tipoProposicion == "Ley Distributiva", let (a, b, c, opExt) = descomponerDistributiva(proposicionLimpia) {
            let opInt: Character = opExt == "∧" ? "∨" : "∧"
            pasos.append(PasoDemostracion(expresion: "\(a)\(opExt)(\(b)\(opInt)\(c))", regla: "Original"))
            pasos.append(PasoDemostracion(expresion: "(\(a)\(opExt)\(b))\(opInt)(\(a)\(opExt)\(c))", regla: "Ley Distributiva"))

        } else if tipoProposicion == "Implicación como Disyunción", let (a, b) = descomponerImplicacionComoDisyuncion(proposicionLimpia) {
            pasos.append(PasoDemostracion(expresion: "¬\(a)∨\(b)", regla: "Original"))
            pasos.append(PasoDemostracion(expresion: "\(agruparSiEsCompuesta(a))→\(b)", regla: "Equivalencia Implicación"))

        } else if tipoProposicion.contains("Implicación"), let partes = separarImplicacionPrincipal(proposicionLimpia) {
            pasos.append(PasoDemostracion(expresion: "\(partes.antecedente)→\(partes.consecuente)", regla: "Original"))
            pasos.append(PasoDemostracion(expresion: "¬\(agruparSiEsCompuesta(partes.antecedente)) ∨ \(partes.consecuente)",
                                           regla: "Equivalencia Implicación"))

        } else if tipoProposicion.contains("Doble Negación") {
            let variable = String(proposicionLimpia.dropFirst(2))
            pasos.append(PasoDemostracion(expresion: "¬¬\(variable)", regla: "Original"))
            pasos.append(PasoDemostracion(expresion: variable, regla: "Doble Negación"))

        } else if tipoProposicion.contains("Conjunción") {
            let operandos = dividirEnNivelSuperior(proposicionLimpia, operador: "∧")
            pasos.append(PasoDemostracion(expresion: operandos.joined(separator: "∧"), regla: "Original"))
            pasos.append(PasoDemostracion(expresion: "Verdadera solo si todas las partes son verdaderas", regla: "Def. Conjunción"))

        } else if tipoProposicion.contains("Disyunción Exclusiva") {
            // OJO: este chequeo va ANTES del de "Disyunción" a secas, porque
            // "Disyunción Exclusiva".contains("Disyunción") también es cierto — si no,
            // el ⊕ caería en la rama genérica de ∨ de abajo.
            let operandos = dividirEnNivelSuperior(proposicionLimpia, operador: "⊕").map(quitarParentesisRedundantes)
            pasos.append(PasoDemostracion(expresion: operandos.joined(separator: "⊕"), regla: "Original"))
            if operandos.count == 2 {
                let a = operandos[0], b = operandos[1]
                pasos.append(PasoDemostracion(expresion: "(\(a)∧¬\(b))∨(¬\(a)∧\(b))", regla: "Equivalencia Disyunción Exclusiva"))
            }
            pasos.append(PasoDemostracion(expresion: "Verdadera solo cuando un número impar de partes son verdaderas (para 2: valores diferentes)",
                                           regla: "Def. Disyunción Exclusiva"))

        } else if tipoProposicion.contains("Disyunción") {
            let operandos = dividirEnNivelSuperior(proposicionLimpia, operador: "∨")
            pasos.append(PasoDemostracion(expresion: operandos.joined(separator: "∨"), regla: "Original"))
            pasos.append(PasoDemostracion(expresion: "Falsa solo si todas las partes son falsas", regla: "Def. Disyunción"))

        } else if tipoProposicion == "Equivalencia Lógica" {
            let operandos = dividirEnNivelSuperior(proposicionLimpia, operador: "↔")
            pasos.append(PasoDemostracion(expresion: operandos.joined(separator: "↔"), regla: "Original"))
            pasos.append(PasoDemostracion(expresion: "Verdadera cuando ambos lados tienen el mismo valor", regla: "Def. Equivalencia"))

        } else if tipoProposicion.contains("Negación") {
            let subExp = String(proposicionLimpia.dropFirst())
            pasos.append(PasoDemostracion(expresion: "¬\(subExp)", regla: "Original"))
            pasos.append(PasoDemostracion(expresion: "Invierte el valor de verdad de \(subExp)", regla: "Def. Negación"))
        }

        if pasos.isEmpty {
            pasos.append(PasoDemostracion(expresion: proposicion, regla: "Proposición atómica"))
        }

        return pasos
    }

    var body: some View {
        VStack {
            Text("Teorema y Demostración")
                .font(.headline)
                .padding(.bottom, 5)
            
            if proposicion.isEmpty {
                Text("Ingrese una proposición para ver el teorema")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Teorema:")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text(teoremaParaProposicion())
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Demostración:")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            ForEach(generarDemostracion()) { paso in
                                VStack(alignment: .leading) {
                                    Text(paso.expresion)
                                        .font(.system(.body, design: .monospaced))
                                    Text("/\(paso.regla)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func teoremaParaProposicion() -> String {
        if tipoProposicion.contains("Tautología") {
            return "⊨ \(proposicion) (Tautología: siempre verdadera)"
        } else if tipoProposicion.contains("Contradicción") {
            return "⊨ ¬(\(proposicion)) (Contradicción: siempre falsa)"
        } else if tipoProposicion.contains("Ley de De Morgan") {
            if let grupo = interiorDeNegacionDeGrupo(proposicion) {
                let operadorInterno: Character = tipoProposicion.contains("Disyunción") ? "∨" : "∧"
                let partes = dividirEnNivelSuperior(grupo, operador: operadorInterno).map(quitarParentesisRedundantes)
                if partes.count == 2 {
                    let operadorContrario: Character = operadorInterno == "∧" ? "∨" : "∧"
                    return "¬(\(partes[0])\(operadorInterno)\(partes[1])) ≡ (¬\(partes[0])\(operadorContrario)¬\(partes[1]))"
                }
            }
        } else if tipoProposicion == "Ley Distributiva" {
            if let (a, b, c, opExt) = descomponerDistributiva(proposicion) {
                let opInt: Character = opExt == "∧" ? "∨" : "∧"
                return "\(a)\(opExt)(\(b)\(opInt)\(c)) ≡ (\(a)\(opExt)\(b))\(opInt)(\(a)\(opExt)\(c))"
            }
        } else if tipoProposicion == "Implicación como Disyunción" {
            if let (a, b) = descomponerImplicacionComoDisyuncion(proposicion) {
                return "\(proposicion) ≡ \(agruparSiEsCompuesta(a))→\(b)"
            }
        } else if tipoProposicion.contains("Implicación") {
            if let partes = separarImplicacionPrincipal(proposicion) {
                return "\(proposicion) ≡ ¬\(agruparSiEsCompuesta(partes.antecedente)) ∨ \(agruparSiEsCompuesta(partes.consecuente))"
            }
        } else if tipoProposicion.contains("Doble Negación") {
            let sinEspacios = proposicion.replacingOccurrences(of: " ", with: "")
            let variable = String(sinEspacios.dropFirst(2))
            return "¬¬\(variable) ≡ \(variable)"
        } else if tipoProposicion.contains("Disyunción Exclusiva") {
            let expr = quitarParentesisRedundantes(proposicion.replacingOccurrences(of: " ", with: ""))
            let operandos = dividirEnNivelSuperior(expr, operador: "⊕").map(quitarParentesisRedundantes)
            if operandos.count == 2 {
                let a = operandos[0], b = operandos[1]
                return "\(a)⊕\(b) ≡ (\(a)∧¬\(b))∨(¬\(a)∧\(b))"
            }
        }
        return proposicion
    }
}

struct HistorialView: View {
    @Binding var historial: [String]
    @Binding var mostrarHistorial: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(historial.reversed(), id: \.self) { item in
                    Text(item)
                }
                .onDelete { indices in
                    historial.remove(atOffsets: indices)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Borrar") {
                        historial.removeAll()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        mostrarHistorial = false
                    }
                }
            }
            .navigationTitle("Historial")
        }
    }
}

struct ActionButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct LogicaProposicionalView_Previews: PreviewProvider {
    static var previews: some View {
        LogicaProposicionalView()
    }
}
