import SwiftUI

// MARK: - Ordenamiento numérico/alfabético compartido

/// Ordena elementos de forma numérica cuando todos son números (evita que "10" quede antes que "2"),
/// y alfabéticamente en caso contrario. Se usa en toda la sección de Lógica de Conjuntos para que
/// resultados, tabla de pertenencia y diagrama de Venn muestren los elementos en el mismo orden.
func ordenarElementosConjunto<S: Sequence>(_ elementos: S) -> [String] where S.Element == String {
    Array(elementos).sorted { a, b in
        if let na = Double(a), let nb = Double(b) {
            return na < nb
        }
        return a.localizedStandardCompare(b) == .orderedAscending
    }
}

struct LogicaConjuntosView: View {
    // Estados para conjuntos
    @State private var conjuntosNumericos: [String] = ["3, 4, 5", "5, 6, 7"]
    @State private var universoNumerico: String = "1, 2, 3, 4, 5, 6, 7, 8, 9, 10"
    @State private var conjuntosAlfabeticos: [String] = ["a, b, c", "b, c, d"]
    @State private var universoAlfabetico: String = "a, b, c, d, e, f, g, h"
    @State private var operacion: String = "Intersección"
    @State private var resultadoNumerico: Set<String> = []
    @State private var resultadoAlfabetico: Set<String> = []
    @State private var mostrarVisualizaciones = true
    @State private var mostrarHistorial = false
    @State private var historial: [String] = []
    @State private var mostrarConfigUniverso = false
    @State private var tipoEntrada = "Numérico"
    // Fórmula que el usuario va armando tocando los botones de conjuntos y
    // símbolos en "Combinación personalizada" (ver combinacionPersonalizadaView
    // más abajo). Es una fórmula libre de verdad: el usuario decide en qué
    // orden y a qué conjuntos le aplica cada símbolo, no un orden fijo.
    @State private var expresionCombinacion: String = ""

    private let operaciones = [
        "Unión", "Intersección", "Diferencia", "Complemento",
        "Ley de Morgan 1", "Ley de Morgan 2", "Doble Negación",
        "Conmutativa Unión", "Conmutativa Intersección",
        "Asociativa Unión", "Asociativa Intersección",
        "Idempotencia Unión", "Idempotencia Intersección",
        "Contradicción", "Distributiva Unión", "Distributiva Intersección"
    ]
    
    private let tiposEntrada = ["Numérico", "Alfabético"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerView()
                    
                    if mostrarConfigUniverso {
                        configuracionUniversoView()
                    }
                    
                    tipoEntradaPickerView()
                    conjuntosInputView()
                    operacionPickerView()
                    actionButtonsView()
                    resultadosView()
                    
                    if mostrarVisualizaciones {
                        visualizacionesView()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Lógica de Conjuntos")
            .onAppear(perform: calcularOperacion)
            .sheet(isPresented: $mostrarHistorial) {
                historialView()
            }
        }
    }
    
    // MARK: - Subviews
    
    private func headerView() -> some View {
        HStack {
            Button(action: { mostrarHistorial.toggle() }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .padding(8)
            }
            
            Spacer()

            Button(action: { mostrarConfigUniverso.toggle() }) {
                Image(systemName: "globe")
                    .font(.title2)
                    .padding(8)
            }
        }
        .padding(.horizontal)
    }
    
    private func configuracionUniversoView() -> some View {
        VStack {
            if tipoEntrada == "Numérico" {
                HStack {
                    Text("Universo Numérico:")
                    TextField("Ej. 1, 2, 3", text: $universoNumerico)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            } else {
                HStack {
                    Text("Universo Alfabético:")
                    TextField("Ej. a, b, c", text: $universoAlfabetico)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            Button("Aplicar") {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                calcularOperacion()
            }
            .padding(.top, 5)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private func tipoEntradaPickerView() -> some View {
        Picker("Tipo de Conjunto", selection: $tipoEntrada) {
            ForEach(tiposEntrada, id: \.self) { tipo in
                Text(tipo).tag(tipo)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .onChange(of: tipoEntrada) { _ in calcularOperacion() }
    }
    
    private func conjuntosInputView() -> some View {
        Group {
            if tipoEntrada == "Numérico" {
                ForEach(0..<conjuntosNumericos.count, id: \.self) { index in
                    HStack {
                        TextField("Conjunto \(index+1)", text: $conjuntosNumericos[index])
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: conjuntosNumericos[index]) { _ in
                                calcularOperacion()
                            }
                        
                        if conjuntosNumericos.count > 1 {
                            Button(action: {
                                conjuntosNumericos.remove(at: index)
                                calcularOperacion()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Button(action: {
                    conjuntosNumericos.append("")
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Agregar Conjunto")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            } else {
                ForEach(0..<conjuntosAlfabeticos.count, id: \.self) { index in
                    HStack {
                        TextField("Conjunto \(index+1)", text: $conjuntosAlfabeticos[index])
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: conjuntosAlfabeticos[index]) { _ in
                                calcularOperacion()
                            }
                        
                        if conjuntosAlfabeticos.count > 1 {
                            Button(action: {
                                conjuntosAlfabeticos.remove(at: index)
                                calcularOperacion()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Button(action: {
                    conjuntosAlfabeticos.append("")
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Agregar Conjunto")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func operacionPickerView() -> some View {
        Menu {
            ForEach(operaciones, id: \.self) { op in
                Button(action: {
                    operacion = op
                    calcularOperacion()
                }) {
                    Text(op)
                }
            }
        } label: {
            HStack {
                Text(operacion)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    private func actionButtonsView() -> some View {
        HStack(spacing: 15) {
            Button(action: borrarCampos) {
                Text("Borrar")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }
    
    private func resultadosView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resultados")
                .font(.headline)
                .padding(.bottom, 5)
            
            if tipoEntrada == "Numérico" {
                Text("Numérico: \(formatearResultado(resultadoNumerico))")
                    .padding(.bottom, 10)
                
                if operacion == "Intersección" && conjuntosNumericos.count >= 2 {
                    mostrarIntersecciones(conjuntos: conjuntosNumericos, resultado: resultadoNumerico)
                        .padding(.bottom, 10)
                }
                
                if operacion == "Contradicción" {
                    mostrarContradicciones(conjuntos: conjuntosNumericos, universo: universoNumerico)
                        .padding(.bottom, 10)
                }
            } else {
                Text("Alfabético: \(formatearResultado(resultadoAlfabetico))")
                    .padding(.bottom, 10)
                
                if operacion == "Intersección" && conjuntosAlfabeticos.count >= 2 {
                    mostrarIntersecciones(conjuntos: conjuntosAlfabeticos, resultado: resultadoAlfabetico)
                        .padding(.bottom, 10)
                }
                
                if operacion == "Contradicción" {
                    mostrarContradicciones(conjuntos: conjuntosAlfabeticos, universo: universoAlfabetico)
                        .padding(.bottom, 10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.bottom, 15)
    }
    
    @ViewBuilder
    private func mostrarIntersecciones(conjuntos: [String], resultado: Set<String>) -> some View {
        let sets = conjuntos.map { limpiarConjunto($0) }
        
        ForEach(0..<sets.count, id: \.self) { i in
            ForEach(i+1..<sets.count, id: \.self) { j in
                let interseccion = sets[i].intersection(sets[j])
                if !interseccion.isEmpty {
                    Text("C\(i+1) ∩ C\(j+1) = \(formatearResultado(interseccion))")
                } else {
                    Text("C\(i+1) ∩ C\(j+1) = ∅")
                        .foregroundColor(.gray)
                }
            }
        }
        
        if conjuntos.count > 2 {
            let interseccionTotal = sets.reduce(sets[0]) { $0.intersection($1) }
            Text("Intersección total = \(formatearResultado(interseccionTotal))")
                .bold()
                .foregroundColor(interseccionTotal.isEmpty ? .gray : .primary)
        }
    }
    
    @ViewBuilder
    private func mostrarContradicciones(conjuntos: [String], universo: String) -> some View {
        let sets = conjuntos.map { limpiarConjunto($0) }
        let universalSet = limpiarConjunto(universo)
        
        VStack(alignment: .leading) {
            ForEach(0..<sets.count, id: \.self) { i in
                let complemento = universalSet.subtracting(sets[i])
                let contradiccion = sets[i].intersection(complemento)
                Text("C\(i+1) ∩ ¬C\(i+1) = \(formatearResultado(contradiccion))")
                    .foregroundColor(contradiccion.isEmpty ? .gray : .red)
            }
        }
    }
    
    private func visualizacionesView() -> some View {
        // Nota: antes estas tres vistas llevaban un .frame(height:) fijo (220/350/120).
        // Con universos de 8-10+ elementos el contenido real (filas de la tabla, círculos
        // + leyenda del diagrama, ecuación larga) supera esa altura fija y SwiftUI recorta
        // la vista, provocando que se vea encimada con la sección siguiente. Se deja que
        // cada tarjeta tome la altura que necesite su contenido.
        VStack(spacing: 30) {
            if tipoEntrada == "Numérico" {
                TablaPertenenciaView(
                    conjuntos: conjuntosNumericos.map { limpiarConjunto($0) },
                    resultado: resultadoNumerico,
                    operacion: operacion,
                    universo: limpiarConjunto(universoNumerico)
                )

                DiagramaVennView(
                    conjuntos: conjuntosNumericos.map { limpiarConjunto($0) },
                    resultado: resultadoNumerico,
                    operacion: operacion,
                    universo: limpiarConjunto(universoNumerico)
                )
                .padding(.horizontal, 20)

            } else {
                TablaPertenenciaView(
                    conjuntos: conjuntosAlfabeticos.map { limpiarConjunto($0) },
                    resultado: resultadoAlfabetico,
                    operacion: operacion,
                    universo: limpiarConjunto(universoAlfabetico)
                )

                DiagramaVennView(
                    conjuntos: conjuntosAlfabeticos.map { limpiarConjunto($0) },
                    resultado: resultadoAlfabetico,
                    operacion: operacion,
                    universo: limpiarConjunto(universoAlfabetico)
                )
                .padding(.horizontal, 20)
            }

            EcuacionFormalView(
                operacion: operacion,
                conjuntos: tipoEntrada == "Numérico" ? conjuntosNumericos : conjuntosAlfabeticos
            )

            combinacionPersonalizadaView(
                sets: (tipoEntrada == "Numérico" ? conjuntosNumericos : conjuntosAlfabeticos)
                    .map { limpiarConjunto($0) },
                universal: limpiarConjunto(tipoEntrada == "Numérico" ? universoNumerico : universoAlfabetico)
            )
        }
        .padding(.vertical, 15)
        .padding(.horizontal)
    }

    // MARK: - Combinación personalizada (fórmula libre, cualquier cantidad de conjuntos)
    //
    // Reescrito a petición: en vez de una cadena fija donde la app decide qué
    // conjuntos van juntos (A con B, B con C, ...), esto es un constructor de
    // fórmula libre: se tocan botones de conjuntos (A, B, C...) y de símbolos
    // (∪ ∩ - ' ( )) en cualquier orden, y el usuario decide exactamente a qué
    // conjunto le aplica cada operación — no está limitado a pares consecutivos.
    // La fórmula armada se evalúa de verdad (parser abajo), no es solo texto.
    //
    // No se agregaron botones separados de "Ley de Morgan", "Absorción", etc.:
    // esas leyes no son símbolos que se insertan, son fórmulas que YA se pueden
    // armar con estos mismos botones. Por ejemplo Ley de Morgan 1 es (A ∪ B)'
    // y se escribe tocando, en orden: A, luego ∪, luego B, luego ), luego '.
    // Un botón aparte de "Ley de Morgan" no le agregaría nada a la fórmula que
    // estos símbolos básicos no puedan escribir ya.
    // Resto de la vista (operación de arriba, tabla, Venn, ecuación) sin cambios.

    private func nombreConjunto(_ index: Int) -> String {
        let letras = ["A", "B", "C", "D", "E", "F"]
        return index < letras.count ? letras[index] : "C\(index + 1)"
    }

    /// Corta la fórmula en tokens: nombres de conjunto (A, B, C... o C7, C8... si
    /// hay más de 6), símbolos de operación (∪ ∩ -) y agrupación (' ( )).
    /// Devuelve nil si encuentra un carácter que no reconoce.
    private func tokenizarExpresionCombinacion(_ expr: String, nombres: [String]) -> [String]? {
        let chars = Array(expr)
        let nombresOrdenados = nombres.sorted { $0.count > $1.count }
        var tokens: [String] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == " " { i += 1; continue }
            if c == "(" || c == ")" || c == "'" || c == "∪" || c == "∩" {
                tokens.append(String(c)); i += 1; continue
            }
            if c == "-" || c == "−" {
                tokens.append("-"); i += 1; continue
            }
            var coincide = false
            for n in nombresOrdenados {
                let nChars = Array(n)
                if i + nChars.count <= chars.count && Array(chars[i..<(i + nChars.count)]) == nChars {
                    tokens.append(n)
                    i += nChars.count
                    coincide = true
                    break
                }
            }
            if !coincide { return nil }
        }
        return tokens
    }

    /// Evalúa la fórmula armada por el usuario. Gramática (precedencia usual de
    /// teoría de conjuntos, igual que ¬/∧/∨ en lógica): complemento (postfijo ')
    /// más fuerte, luego ∩ y -, luego ∪ al final; ( ) agrupa. Devuelve nil si la
    /// fórmula está incompleta o mal formada (paréntesis sin cerrar, etc.).
    private func evaluarExpresionCombinacion(_ expr: String, nombres: [String], sets: [Set<String>], universal: Set<String>) -> Set<String>? {
        guard let tokens = tokenizarExpresionCombinacion(expr, nombres: nombres), !tokens.isEmpty else { return nil }
        var pos = 0
        func peek() -> String? { pos < tokens.count ? tokens[pos] : nil }
        func avanzar() { pos += 1 }

        func parsePrimario() -> Set<String>? {
            guard let t = peek() else { return nil }
            if t == "(" {
                avanzar()
                guard let interior = parseUnion(), peek() == ")" else { return nil }
                avanzar()
                return interior
            }
            if let idx = nombres.firstIndex(of: t) {
                avanzar()
                return sets[idx]
            }
            return nil
        }

        func parseComplemento() -> Set<String>? {
            guard var valor = parsePrimario() else { return nil }
            while peek() == "'" {
                avanzar()
                valor = universal.subtracting(valor)
            }
            return valor
        }

        func parseInterseccion() -> Set<String>? {
            guard var valor = parseComplemento() else { return nil }
            while let t = peek(), t == "∩" || t == "-" {
                avanzar()
                guard let derecho = parseComplemento() else { return nil }
                valor = (t == "∩") ? valor.intersection(derecho) : valor.subtracting(derecho)
            }
            return valor
        }

        func parseUnion() -> Set<String>? {
            guard var valor = parseInterseccion() else { return nil }
            while peek() == "∪" {
                avanzar()
                guard let derecho = parseInterseccion() else { return nil }
                valor = valor.union(derecho)
            }
            return valor
        }

        guard let resultado = parseUnion(), pos == tokens.count else { return nil }
        return resultado
    }

    // Botones de leyes: agregado a petición. Cada una NO es un símbolo básico
    // nuevo para el parser (el parser solo conoce ∪ ∩ - ' ( )) — es un atajo
    // que inserta, con esos mismos símbolos, el patrón de esa ley ya armado
    // con los conjuntos actuales (los primeros 1-3 que haya), para que el
    // usuario no tenga que escribirlo letra por letra. Como el patrón queda
    // hecho de los símbolos básicos, el resultado sí se calcula de verdad —
    // por ejemplo tocar "Contradicción" inserta A∩A', y el resultado que se
    // muestra abajo será el conjunto vacío, demostrando la ley con datos reales.
    //
    // Unificado a petición: los símbolos básicos (∪ ∩ - ' ( )) y los de las
    // leyes están en UNA sola lista/rejilla con el mismo tamaño de botón, en
    // vez de dos secciones separadas con tamaños distintos.
    private let botonesSimbolosYLeyes: [String] = [
        "∪", "∩", "-", "'", "(", ")",
        "(DM1)", "(DM2)", "(¬¬)", "∪(c)", "∩(c)", "∪(a)", "∩(a)", "∪(i)", "∩(i)", "∅", "∪(d)", "∩(d)"
    ]

    private let leySegunEtiqueta: [String: String] = [
        "(DM1)": "Ley de Morgan 1",
        "(DM2)": "Ley de Morgan 2",
        "(¬¬)": "Doble Negación",
        "∪(c)": "Conmutativa Unión",
        "∩(c)": "Conmutativa Intersección",
        "∪(a)": "Asociativa Unión",
        "∩(a)": "Asociativa Intersección",
        "∪(i)": "Idempotencia Unión",
        "∩(i)": "Idempotencia Intersección",
        "∅": "Contradicción",
        "∪(d)": "Distributiva Unión",
        "∩(d)": "Distributiva Intersección",
    ]

    /// El patrón que arma esa ley con los conjuntos actuales (puros símbolos
    /// básicos, para que el parser lo evalúe igual que cualquier otra fórmula).
    private func snippetParaLey(_ ley: String, nombres: [String]) -> String {
        guard let a = nombres.first else { return "" }
        let b = nombres.count > 1 ? nombres[1] : a
        let c = nombres.count > 2 ? nombres[2] : b
        switch ley {
        case "Ley de Morgan 1": return "(\(a)∪\(b))'"
        case "Ley de Morgan 2": return "(\(a)∩\(b))'"
        case "Doble Negación": return "\(a)''"
        case "Conmutativa Unión": return "\(b)∪\(a)"
        case "Conmutativa Intersección": return "\(b)∩\(a)"
        case "Asociativa Unión": return "(\(a)∪\(b))∪\(c)"
        case "Asociativa Intersección": return "(\(a)∩\(b))∩\(c)"
        case "Idempotencia Unión": return "\(a)∪\(a)"
        case "Idempotencia Intersección": return "\(a)∩\(a)"
        case "Contradicción": return "\(a)∩\(a)'"
        case "Distributiva Unión": return "\(a)∪(\(b)∩\(c))"
        case "Distributiva Intersección": return "\(a)∩(\(b)∪\(c))"
        default: return ""
        }
    }

    /// Lo que hay que agregar a la fórmula al tocar o arrastrar ese botón: el
    /// símbolo tal cual si es básico, o el patrón armado si es una ley.
    private func tokenParaBoton(_ etiqueta: String, nombres: [String]) -> String {
        if let ley = leySegunEtiqueta[etiqueta] {
            return snippetParaLey(ley, nombres: nombres)
        }
        return etiqueta
    }

    /// Envuelve un texto para poder arrastrarlo (drag & drop) con las APIs
    /// clásicas de SwiftUI/UIKit (NSItemProvider), en vez de las más nuevas
    /// (.draggable/.dropDestination) para no depender de una versión exacta
    /// de iOS más nueva que la que ya usa el resto del proyecto.
    private func proveedorTexto(_ texto: String) -> NSItemProvider {
        NSItemProvider(object: texto as NSString)
    }

    // Mismos colores y mismo estilo que el Diagrama de Venn de esta vista (ver
    // struct DiagramaVennView: `colors` + .stroke(color) + .fill(color.opacity(0.15))
    // en sus círculos) — a petición, para que se vea consistente con el resto
    // de la app: bordecito de color y relleno transparente, no un botón sólido.
    private let coloresBotonesCombinacion: [Color] = [.blue, .green, .orange, .purple, .pink, .yellow]

    private func colorBoton(_ indice: Int) -> Color {
        coloresBotonesCombinacion[indice % coloresBotonesCombinacion.count]
    }

    /// Botón cuadrado (mismo tamaño para todos, esquinas redondeadas, no
    /// circular) que se puede ARRASTRAR hasta la fórmula, y opcionalmente
    /// también TOCAR para insertarlo de una vez (permitirToque). Importante:
    /// es un Text con gestos, no un Button — un Button con .onDrag encima le
    /// "roba" el gesto de arrastrar y nunca llega a iniciar el drag (eso era
    /// lo que impedía arrastrar antes). A petición, tanto "Conjuntos" como
    /// "Símbolos y leyes" ahora solo se arrastran (permitirToque: false) —
    /// tocarlos ya no hace nada — porque tocar de camino a arrastrar
    /// insertaba el símbolo de una vez y eso disparaba el salto de scroll
    /// hasta arriba; ahora nada se inserta hasta que sueltas el botón sobre
    /// la fórmula de arriba.
    @ViewBuilder
    private func botonCombinacion(_ etiqueta: String, color: Color, deshabilitado: Bool, permitirToque: Bool = true, alTocar: @escaping () -> Void, alArrastrar: @escaping () -> NSItemProvider) -> some View {
        Text(etiqueta)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundColor(color)
            .frame(width: 50, height: 42)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 2))
            .opacity(deshabilitado ? 0.35 : 1)
            .contentShape(Rectangle())
            .onTapGesture { if permitirToque && !deshabilitado { alTocar() } }
            .onDrag { alArrastrar() }
    }

    /// Reparte `count` índices (0..<count) en filas de a lo más `columnas`.
    /// Antes los botones de "Conjuntos" y "Símbolos y leyes" iban en un
    /// LazyVGrid — pero un LazyVGrid dentro de un ScrollView, apenas empieza
    /// un .onDrag, dispara un bug conocido de SwiftUI/UIKit donde el
    /// ScrollView entero salta hasta arriba (porque el grid, al ser "lazy",
    /// recalcula su layout justo cuando arranca el drag). Al usar en su lugar
    /// un VStack de HStacks normal (nada "lazy": todo ya está calculado de
    /// antemano) ese re-layout a medio drag ya no pasa, y el salto se quita.
    /// El resultado visual es el mismo (mismas filas de 5 en 5).
    private func filasDeIndices(count: Int, columnas: Int) -> [[Int]] {
        guard count > 0, columnas > 0 else { return [] }
        return stride(from: 0, to: count, by: columnas).map { inicio in
            Array(inicio..<min(inicio + columnas, count))
        }
    }

    /// Va evaluando cada prefijo de la fórmula (letra por letra/símbolo por
    /// símbolo) y se queda con los que ya son una sub-fórmula válida — así se
    /// puede mostrar, a petición, el resultado de cada "pedazo" a medida que
    /// se arma la fórmula completa (p.ej. armando A∩B-C: primero el resultado
    /// de A∩B solo, y ya al final el de A∩B-C completo), no solo el final.
    private func pasosCombinacion(_ expr: String, nombres: [String], sets: [Set<String>], universal: Set<String>) -> [(prefijo: String, resultado: Set<String>)] {
        guard let tokens = tokenizarExpresionCombinacion(expr, nombres: nombres), !tokens.isEmpty else { return [] }
        var pasos: [(String, Set<String>)] = []
        var acumulado = ""
        for token in tokens {
            acumulado += token
            if let r = evaluarExpresionCombinacion(acumulado, nombres: nombres, sets: sets, universal: universal) {
                pasos.append((acumulado, r))
            }
        }
        return pasos
    }

    private func combinacionPersonalizadaView(sets: [Set<String>], universal: Set<String>) -> some View {
        let nombres = (0..<sets.count).map { nombreConjunto($0) }
        // resultado: el de la fórmula COMPLETA tal como está ahora (nil si está
        // incompleta/mal armada, para el aviso de error de siempre).
        let resultado = evaluarExpresionCombinacion(expresionCombinacion, nombres: nombres, sets: sets, universal: universal)
        // pasos: el resultado de cada sub-fórmula válida a medida que se arma
        // (a petición). Si la fórmula completa ya es válida, su resultado es
        // el último paso — no se repite aparte, ya se muestra en "Resultado".
        let pasos = pasosCombinacion(expresionCombinacion, nombres: nombres, sets: sets, universal: universal)
        let pasosIntermedios = (resultado != nil) ? Array(pasos.dropLast()) : pasos

        return VStack(alignment: .leading, spacing: 10) {
            Text("Combinación personalizada")
                .font(.headline)

            Text("Arma tu propia fórmula tocando los conjuntos y símbolos de abajo, en el orden que quieras: tú eliges a cuál conjunto le aplicas cada operación.")
                .font(.caption)
                .foregroundColor(.secondary)

            // Recordatorio de qué tiene cada conjunto (con sus elementos), para
            // no tener que subir a verlo mientras se arma la fórmula abajo. Los
            // botones de más abajo, en cambio, muestran solo la letra (A, B, C),
            // no los elementos — ahí solo importa a cuál le aplicas cada símbolo.
            if !sets.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(0..<sets.count, id: \.self) { i in
                        Text("\(nombres[i]) = \(formatearResultado(sets[i]))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.5))
                .cornerRadius(8)
            }

            Text(expresionCombinacion.isEmpty ? "Toca o arrastra aquí los botones de abajo para empezar..." : expresionCombinacion)
                .font(.system(.title3, design: .monospaced))
                .foregroundColor(expresionCombinacion.isEmpty ? .secondary : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 2))
                .cornerRadius(8)
                .onDrop(of: ["public.text"], isTargeted: nil) { providers in
                    for provider in providers {
                        _ = provider.loadObject(ofClass: NSString.self) { objeto, _ in
                            if let texto = objeto as? NSString {
                                DispatchQueue.main.async {
                                    expresionCombinacion += texto as String
                                }
                            }
                        }
                    }
                    return true
                }

            if !sets.isEmpty {
                Text("Conjuntos (arrástralos hasta la fórmula de arriba):")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(filasDeIndices(count: nombres.count, columnas: 5), id: \.self) { fila in
                        HStack(spacing: 6) {
                            ForEach(fila, id: \.self) { i in
                                let n = nombres[i]
                                botonCombinacion(
                                    n, color: colorBoton(i), deshabilitado: false, permitirToque: false,
                                    alTocar: { expresionCombinacion += n },
                                    alArrastrar: { proveedorTexto(n) }
                                )
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            Text("Símbolos y leyes (arrástralos hasta la fórmula de arriba):")
                .font(.caption2)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(filasDeIndices(count: botonesSimbolosYLeyes.count, columnas: 5), id: \.self) { fila in
                    HStack(spacing: 6) {
                        ForEach(fila, id: \.self) { i in
                            let etiqueta = botonesSimbolosYLeyes[i]
                            let deshabilitado = leySegunEtiqueta[etiqueta] != nil && sets.isEmpty
                            botonCombinacion(
                                etiqueta, color: colorBoton(i), deshabilitado: deshabilitado, permitirToque: false,
                                alTocar: { expresionCombinacion += tokenParaBoton(etiqueta, nombres: nombres) },
                                alArrastrar: { proveedorTexto(tokenParaBoton(etiqueta, nombres: nombres)) }
                            )
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            Text("∪ unión · ∩ intersección · - diferencia · ' complemento · DM1/DM2 = Ley de Morgan 1/2 · (¬¬) = Doble Negación · (c) = Conmutativa · (a) = Asociativa · (i) = Idempotencia · ∅ = Contradicción · (d) = Distributiva")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack {
                Button {
                    if !expresionCombinacion.isEmpty { expresionCombinacion.removeLast() }
                } label: {
                    Label("Borrar", systemImage: "delete.left")
                }
                Spacer()
                Button(role: .destructive) {
                    expresionCombinacion = ""
                } label: {
                    Text("Limpiar todo")
                }
            }
            .font(.caption)

            if sets.isEmpty {
                Text("Agrega al menos un conjunto arriba para usar esta combinación.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !expresionCombinacion.isEmpty {
                // Pasos intermedios: a petición, para que sea didáctico, se
                // muestra el resultado de cada "pedazo" ya armado antes de
                // llegar al final (p.ej. primero A∪B, y ya después (A∪B)-C).
                if !pasosIntermedios.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pasos:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ForEach(Array(pasosIntermedios.enumerated()), id: \.offset) { _, paso in
                            Text("\(paso.prefijo) = \(formatearResultado(paso.resultado))")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 2)
                }

                if let resultado {
                    Text("Resultado (de esta combinación): \(formatearResultado(resultado))")
                        .bold()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                } else {
                    Text("Fórmula incompleta o con un error (revisa paréntesis y símbolos).")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Text("Tip: con estos mismos símbolos puedes armar tú mismo cualquier ley, por ejemplo Ley de Morgan como (A ∪ B)' o A' ∩ B'.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    private func historialView() -> some View {
        NavigationView {
            List {
                ForEach(historial.reversed(), id: \.self) { item in
                    Text(item)
                }
                .onDelete { indices in
                    let reversedIndices = indices.map { historial.count - 1 - $0 }
                    historial.remove(atOffsets: IndexSet(reversedIndices))
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
            .navigationTitle("Historial (\(historial.count))")
        }
    }
    
    // MARK: - Logic Functions
    
    private func calcularOperacion() {
        if tipoEntrada == "Numérico" {
            calcularOperacionNumerica()
        } else {
            calcularOperacionAlfabetica()
        }
    }
    
    private func calcularOperacionNumerica() {
        guard !conjuntosNumericos.isEmpty else {
            resultadoNumerico = []
            return
        }
        
        let sets = conjuntosNumericos.map { limpiarConjunto($0) }
        let universal = limpiarConjunto(universoNumerico)
        
        switch operacion {
        case "Unión":
            resultadoNumerico = sets.reduce(Set<String>()) { $0.union($1) }
        case "Intersección":
            resultadoNumerico = sets.reduce(sets[0]) { $0.intersection($1) }
        case "Diferencia":
            resultadoNumerico = sets.count >= 2 ? sets[0].subtracting(sets[1]) : Set<String>()
        case "Complemento":
            resultadoNumerico = universal.subtracting(sets.first ?? Set<String>())
            
        case "Ley de Morgan 1":
            if sets.count >= 2 {
                let union = sets[0].union(sets[1])
                resultadoNumerico = universal.subtracting(union)
            } else {
                resultadoNumerico = []
            }
            
        case "Ley de Morgan 2":
            if sets.count >= 2 {
                let interseccion = sets[0].intersection(sets[1])
                resultadoNumerico = universal.subtracting(interseccion)
            } else {
                resultadoNumerico = []
            }
            
        case "Doble Negación":
            if !sets.isEmpty {
                let complemento = universal.subtracting(sets[0])
                resultadoNumerico = universal.subtracting(complemento)
            } else {
                resultadoNumerico = []
            }
            
        case "Conmutativa Unión":
            if sets.count >= 2 {
                resultadoNumerico = sets[1].union(sets[0])
            } else {
                resultadoNumerico = sets.first ?? []
            }
            
        case "Conmutativa Intersección":
            if sets.count >= 2 {
                resultadoNumerico = sets[1].intersection(sets[0])
            } else {
                resultadoNumerico = sets.first ?? []
            }
            
        case "Asociativa Unión":
            if sets.count >= 3 {
                let ladoIzq = sets[0].union(sets[1]).union(sets[2])
                let ladoDer = sets[0].union(sets[1].union(sets[2]))
                resultadoNumerico = ladoIzq
            } else if sets.count >= 2 {
                resultadoNumerico = sets[0].union(sets[1])
            } else {
                resultadoNumerico = sets.first ?? []
            }
            
        case "Asociativa Intersección":
            if sets.count >= 3 {
                let ladoIzq = sets[0].intersection(sets[1]).intersection(sets[2])
                let ladoDer = sets[0].intersection(sets[1].intersection(sets[2]))
                resultadoNumerico = ladoIzq
            } else if sets.count >= 2 {
                resultadoNumerico = sets[0].intersection(sets[1])
            } else {
                resultadoNumerico = sets.first ?? []
            }
            
        case "Idempotencia Unión":
            if !sets.isEmpty {
                resultadoNumerico = sets[0].union(sets[0])
            } else {
                resultadoNumerico = []
            }
            
        case "Idempotencia Intersección":
            if !sets.isEmpty {
                resultadoNumerico = sets[0].intersection(sets[0])
            } else {
                resultadoNumerico = []
            }
            
        case "Contradicción":
            var contradicciones: Set<String> = []
            for set in sets {
                let complemento = universal.subtracting(set)
                contradicciones.formUnion(set.intersection(complemento))
            }
            resultadoNumerico = contradicciones
            
        case "Distributiva Unión":
            if sets.count >= 3 {
                let ladoIzq = sets[0].union(sets[1].intersection(sets[2]))
                let ladoDer = (sets[0].union(sets[1])).intersection(sets[0].union(sets[2]))
                resultadoNumerico = ladoIzq
            } else {
                resultadoNumerico = []
            }
            
        case "Distributiva Intersección":
            if sets.count >= 3 {
                let ladoIzq = sets[0].intersection(sets[1].union(sets[2]))
                let ladoDer = (sets[0].intersection(sets[1])).union(sets[0].intersection(sets[2]))
                resultadoNumerico = ladoIzq
            } else {
                resultadoNumerico = []
            }
            
        default:
            resultadoNumerico = []
        }
        
        let conjuntosStr = conjuntosNumericos.enumerated().map { "\($0+1)=\($1)" }.joined(separator: ", ")
        let entrada = "[Num] \(operacion): \(conjuntosStr) → \(formatearResultado(resultadoNumerico))"
        if !historial.contains(entrada) {
            historial.append(entrada)
        }
    }
    
    private func calcularOperacionAlfabetica() {
        guard !conjuntosAlfabeticos.isEmpty else {
            resultadoAlfabetico = []
            return
        }
        
        let sets = conjuntosAlfabeticos.map { limpiarConjunto($0) }
        let universal = limpiarConjunto(universoAlfabetico)
        
        switch operacion {
        case "Unión":
            resultadoAlfabetico = sets.reduce(Set<String>()) { $0.union($1) }
        case "Intersección":
            resultadoAlfabetico = sets.reduce(sets[0]) { $0.intersection($1) }
        case "Diferencia":
            resultadoAlfabetico = sets.count >= 2 ? sets[0].subtracting(sets[1]) : Set<String>()
        case "Complemento":
            resultadoAlfabetico = universal.subtracting(sets.first ?? Set<String>())
            
        case "Ley de Morgan 1":
            if sets.count >= 2 {
                let union = sets[0].union(sets[1])
                resultadoAlfabetico = universal.subtracting(union)
            } else {
                resultadoAlfabetico = []
            }
            
        case "Ley de Morgan 2":
            if sets.count >= 2 {
                let interseccion = sets[0].intersection(sets[1])
                resultadoAlfabetico = universal.subtracting(interseccion)
            } else {
                resultadoAlfabetico = []
            }
            
        case "Doble Negación":
            if !sets.isEmpty {
                let complemento = universal.subtracting(sets[0])
                resultadoAlfabetico = universal.subtracting(complemento)
            } else {
                resultadoAlfabetico = []
            }
            
        case "Conmutativa Unión":
            if sets.count >= 2 {
                resultadoAlfabetico = sets[1].union(sets[0])
            } else {
                resultadoAlfabetico = sets.first ?? []
            }
            
        case "Conmutativa Intersección":
            if sets.count >= 2 {
                resultadoAlfabetico = sets[1].intersection(sets[0])
            } else {
                resultadoAlfabetico = sets.first ?? []
            }
            
        case "Asociativa Unión":
            if sets.count >= 3 {
                let ladoIzq = sets[0].union(sets[1]).union(sets[2])
                let ladoDer = sets[0].union(sets[1].union(sets[2]))
                resultadoAlfabetico = ladoIzq
            } else if sets.count >= 2 {
                resultadoAlfabetico = sets[0].union(sets[1])
            } else {
                resultadoAlfabetico = sets.first ?? []
            }
            
        case "Asociativa Intersección":
            if sets.count >= 3 {
                let ladoIzq = sets[0].intersection(sets[1]).intersection(sets[2])
                let ladoDer = sets[0].intersection(sets[1].intersection(sets[2]))
                resultadoAlfabetico = ladoIzq
            } else if sets.count >= 2 {
                resultadoAlfabetico = sets[0].intersection(sets[1])
            } else {
                resultadoAlfabetico = sets.first ?? []
            }
            
        case "Idempotencia Unión":
            if !sets.isEmpty {
                resultadoAlfabetico = sets[0].union(sets[0])
            } else {
                resultadoAlfabetico = []
            }
            
        case "Idempotencia Intersección":
            if !sets.isEmpty {
                resultadoAlfabetico = sets[0].intersection(sets[0])
            } else {
                resultadoAlfabetico = []
            }
            
        case "Contradicción":
            var contradicciones: Set<String> = []
            for set in sets {
                let complemento = universal.subtracting(set)
                contradicciones.formUnion(set.intersection(complemento))
            }
            resultadoAlfabetico = contradicciones
            
        case "Distributiva Unión":
            if sets.count >= 3 {
                let ladoIzq = sets[0].union(sets[1].intersection(sets[2]))
                let ladoDer = (sets[0].union(sets[1])).intersection(sets[0].union(sets[2]))
                resultadoAlfabetico = ladoIzq
            } else {
                resultadoAlfabetico = []
            }
            
        case "Distributiva Intersección":
            if sets.count >= 3 {
                let ladoIzq = sets[0].intersection(sets[1].union(sets[2]))
                let ladoDer = (sets[0].intersection(sets[1])).union(sets[0].intersection(sets[2]))
                resultadoAlfabetico = ladoIzq
            } else {
                resultadoAlfabetico = []
            }
            
        default:
            resultadoAlfabetico = []
        }
        
        let conjuntosStr = conjuntosAlfabeticos.enumerated().map { "\($0+1)=\($1)" }.joined(separator: ", ")
        let entrada = "[Alf] \(operacion): \(conjuntosStr) → \(formatearResultado(resultadoAlfabetico))"
        if !historial.contains(entrada) {
            historial.append(entrada)
        }
    }
    
    private func borrarCampos() {
        if tipoEntrada == "Numérico" {
            conjuntosNumericos = ["", ""]
            resultadoNumerico = []
        } else {
            conjuntosAlfabeticos = ["", ""]
            resultadoAlfabetico = []
        }
        operacion = "Unión"
    }
    
    private func limpiarConjunto(_ texto: String) -> Set<String> {
        Set(texto.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }
    
    private func formatearResultado(_ conjunto: Set<String>) -> String {
        conjunto.isEmpty ? "∅" : "{\(ordenarElementosConjunto(conjunto).joined(separator: ", "))}"
    }
}

// MARK: - Auxiliary Views

struct TablaPertenenciaView: View {
    let conjuntos: [Set<String>]
    let resultado: Set<String>
    let operacion: String
    let universo: Set<String>
    
    var elementos: [String] {
        if operacion == "Complemento" {
            return ordenarElementosConjunto(universo)
        }
        return ordenarElementosConjunto(conjuntos.reduce(Set<String>(), { $0.union($1) }))
    }
    
    var body: some View {
        VStack {
            Text("Tabla de Pertenencia")
                .font(.headline)
                .padding(.bottom, 5)
            
            ScrollView(.horizontal) {
                HStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Elemento").bold()
                        ForEach(elementos, id: \.self) { elemento in
                            Text(elemento)
                        }
                    }
                    .frame(width: 70)
                    
                    ForEach(0..<conjuntos.count, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("∈ \(index+1)").bold()
                            ForEach(elementos, id: \.self) { elemento in
                                Text(conjuntos[index].contains(elemento) ? "✓" : "✗")
                            }
                        }
                        .frame(width: 50)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resultado").bold()
                        ForEach(elementos, id: \.self) { elemento in
                            Text(resultado.contains(elemento) ? "✓" : "✗")
                        }
                    }
                    .frame(width: 70)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct DiagramaVennView: View {
    let conjuntos: [Set<String>]
    let resultado: Set<String>
    let operacion: String
    let universo: Set<String>

    private let maxCircles = 6
    private let circleSize: CGFloat = 120
    private let elementFontSize: CGFloat = 10
    private let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .yellow]
    private let elementoSize: CGFloat = 20

    // Dominio completo a mostrar: unión de todos los conjuntos ingresados, el universo y el
    // resultado, para que ningún elemento (por ejemplo uno que esté en un conjunto pero no se
    // haya incluido en el universo) desaparezca del diagrama.
    private var dominioCompleto: Set<String> {
        let elementosConjuntos = conjuntos.reduce(Set<String>()) { $0.union($1) }
        if operacion == "Complemento" {
            return universo.union(elementosConjuntos)
        }
        return universo.union(elementosConjuntos).union(resultado)
    }

    private var elementosOrdenados: [String] {
        ordenarElementosConjunto(dominioCompleto)
    }

    private var elementosAMostrar: [String] {
        let todos = elementosOrdenados
        return todos.count > 20 ? Array(todos.prefix(20)) : todos
    }

    private var mostrarAdvertencia: Bool {
        dominioCompleto.count > 20
    }

    // Elementos visibles que no pertenecen a ninguno de los conjuntos ingresados (se ubican
    // fuera de los círculos, repartidos de forma estable para que no "brinquen" al redibujar).
    private var elementosFueraDeConjuntos: [String] {
        elementosAMostrar.filter { elemento in !conjuntos.contains { $0.contains(elemento) } }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Diagrama de Venn")
                .font(.headline)
                .padding(.bottom, 5)

            if mostrarAdvertencia {
                Text("Mostrando 20 de \(dominioCompleto.count) elementos")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    .frame(width: circleSize * 2.2, height: circleSize * 2.2)
                    .background(Color.gray.opacity(0.08))

                if operacion == "Contradicción" {
                    diagramaContradiccion()
                } else {
                    ForEach(0..<min(conjuntos.count, maxCircles), id: \.self) { index in
                        Circle()
                            .stroke(colors[index % colors.count], lineWidth: 2.5)
                            .fill(colors[index % colors.count].opacity(0.15))
                            .frame(width: circleSize, height: circleSize)
                            .offset(offsetForCircle(index: index, total: min(conjuntos.count, maxCircles)))
                    }

                    ForEach(elementosAMostrar, id: \.self) { elemento in
                        let enResultado = resultado.contains(elemento)
                        let enConjuntos = conjuntos.contains { $0.contains(elemento) }

                        elementoView(elemento: elemento,
                                   destacado: enResultado,
                                   enConjunto: enConjuntos)
                            .offset(positionForElement(elemento: elemento,
                                  enResult: enResultado))
                    }

                    ForEach(0..<min(conjuntos.count, maxCircles), id: \.self) { index in
                        Text(labelForSet(index: index))
                            .font(.system(size: elementFontSize + 2, weight: .bold))
                            .foregroundColor(colors[index % colors.count])
                            .offset(labelOffsetForSet(index: index,
                                                     total: min(conjuntos.count, maxCircles)))
                    }
                }

                if resultado.isEmpty && operacion != "Contradicción" {
                    Text("∅")
                        .font(.system(size: elementFontSize * 1.8, weight: .bold))
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Circle().fill(Color.white))
                }
            }
            .frame(height: 300)
            
            ScrollView(.horizontal) {
                HStack(spacing: 15) {
                    ForEach(0..<conjuntos.count, id: \.self) { index in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colors[index % colors.count])
                                .frame(width: 14, height: 14)
                            Text("\(labelForSet(index: index)) (Conjunto \(index + 1))")
                                .font(.caption)
                        }
                    }
                    
                    if !resultado.isEmpty {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 14, height: 14)
                            Text("Resultado")
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 10)
    }
    
    @ViewBuilder
    private func elementoView(elemento: String, destacado: Bool, enConjunto: Bool) -> some View {
        let tamano = enConjunto ? elementoSize : elementoSize * 0.8
        let colorFondo = destacado ? Color.red : (enConjunto ? Color.blue.opacity(0.7) : Color.gray.opacity(0.7))
        
        Text(elemento)
            .font(.system(size: elementFontSize, weight: .bold))
            .frame(width: tamano, height: tamano)
            .background(Circle().fill(colorFondo))
            .overlay(Circle().stroke(Color.white, lineWidth: 1))
            .foregroundColor(.white)
    }
    
    // IMPORTANTE: la posición de cada elemento dependía únicamente de QUÉ conjuntos lo
    // contienen (o de la operación), nunca del elemento en sí. Eso hacía que todos los
    // elementos de una misma región (por ejemplo, todos los que están solo en el
    // conjunto A, o todos los que están en la intersección de A y B) cayeran exactamente
    // en el mismo punto y se taparan entre ellos — visualmente solo se veía el último
    // que se dibujaba. Ahora se calcula esa misma "ancla" de región y luego se reparten
    // (jitter) los elementos que comparten región en anillos concéntricos, para que
    // todos queden visibles sin importar cuántos conjuntos se agreguen.
    private func positionForElement(elemento: String, enResult: Bool = false) -> CGSize {
        let ancla = anclaBase(elemento: elemento, enResult: enResult)
        let jitter = jitterParaElemento(elemento, enResult: enResult)
        return CGSize(width: ancla.width + jitter.width, height: ancla.height + jitter.height)
    }

    private func anclaBase(elemento: String, enResult: Bool) -> CGSize {
        let setsContainingElement = conjuntos.enumerated().filter { $0.element.contains(elemento) }.map { $0.offset }

        if enResult {
            switch operacion {
            case "Unión":
                if setsContainingElement.count > 0 {
                    return positionInUnion(setsContainingElement: setsContainingElement)
                }
            case "Intersección":
                if setsContainingElement.count == conjuntos.count {
                    return positionInIntersection()
                } else {
                    return positionInUnion(setsContainingElement: setsContainingElement)
                }
            case "Diferencia":
                if setsContainingElement.count == 1 && setsContainingElement[0] == 0 {
                    return positionInDifference()
                }
            case "Complemento":
                return positionInComplement(elemento: elemento)
            default:
                break
            }
        }

        guard !setsContainingElement.isEmpty else {
            return posicionFueraDeConjuntos(elemento: elemento)
        }

        if setsContainingElement.count > 1 {
            let total = min(conjuntos.count, maxCircles)
            let angles = setsContainingElement.map { Double($0) * (2 * Double.pi / Double(total)) - Double.pi / 2 }

            let avgAngle = atan2(
                angles.map { sin($0) }.reduce(0, +) / Double(angles.count),
                angles.map { cos($0) }.reduce(0, +) / Double(angles.count))

            let distance = circleSize * 0.2

            return CGSize(
                width: CGFloat(cos(avgAngle)) * distance,
                height: CGFloat(sin(avgAngle)) * distance
            )
        } else {
            let index = setsContainingElement[0]
            let total = min(conjuntos.count, maxCircles)
            let angle = Double(index) * (2 * Double.pi / Double(total)) - Double.pi / 2

            let distance = circleSize * 0.6
            return CGSize(
                width: CGFloat(cos(angle)) * distance,
                height: CGFloat(sin(angle)) * distance
            )
        }
    }

    /// Identifica la "región" del diagrama a la que cae un elemento, replicando la misma
    /// lógica de anclaBase(). Los elementos con la misma clave comparten ancla y por eso
    /// necesitan repartirse (jitter) para no encimarse.
    private func claveDeRegion(elemento: String, enResult: Bool) -> String {
        let setsContainingElement = conjuntos.enumerated().filter { $0.element.contains(elemento) }.map { $0.offset }.sorted()

        if enResult {
            switch operacion {
            case "Unión":
                if !setsContainingElement.isEmpty {
                    return "union-\(setsContainingElement.map(String.init).joined(separator: "_"))"
                }
            case "Intersección":
                if setsContainingElement.count == conjuntos.count {
                    return "interseccion-total"
                } else {
                    return "union-\(setsContainingElement.map(String.init).joined(separator: "_"))"
                }
            case "Diferencia":
                if setsContainingElement.count == 1 && setsContainingElement[0] == 0 {
                    return "diferencia"
                }
            case "Complemento":
                return "complemento"
            default:
                break
            }
        }

        if setsContainingElement.isEmpty {
            return "fuera"
        }
        return "miembros-\(setsContainingElement.map(String.init).joined(separator: "_"))"
    }

    /// Todos los elementos visibles agrupados por la región del diagrama que les toca.
    private func elementosPorRegion(enResultLookup: (String) -> Bool) -> [String: [String]] {
        Dictionary(grouping: elementosAMostrar) { elemento in
            claveDeRegion(elemento: elemento, enResult: enResultLookup(elemento))
        }
    }

    /// Desplazamiento adicional para que los elementos que comparten región no se
    /// dibujen exactamente uno encima del otro. Las regiones "fuera" y "complemento" ya
    /// se reparten por su cuenta (posicionFueraDeConjuntos / positionInComplement), así
    /// que aquí no se les añade nada extra.
    private func jitterParaElemento(_ elemento: String, enResult: Bool) -> CGSize {
        let clave = claveDeRegion(elemento: elemento, enResult: enResult)
        guard clave != "fuera", clave != "complemento" else { return .zero }

        let grupo = elementosPorRegion { self.resultado.contains($0) }[clave] ?? [elemento]
        guard let idx = grupo.firstIndex(of: elemento) else { return .zero }
        return offsetEnAnillos(index: idx, total: grupo.count)
    }

    /// Reparte hasta "total" elementos en anillos concéntricos alrededor de un ancla
    /// (hasta 6 por anillo), para que ninguno quede tapado por otro.
    private func offsetEnAnillos(index: Int, total: Int) -> CGSize {
        guard total > 1 else { return .zero }
        let porAnillo = 6
        let anillo = index / porAnillo
        let posicionEnAnillo = index % porAnillo
        let elementosEnEsteAnillo = min(porAnillo, total - anillo * porAnillo)
        let radio = CGFloat(anillo + 1) * 15
        let angle = (Double(posicionEnAnillo) / Double(max(elementosEnEsteAnillo, 1))) * 2 * Double.pi
        return CGSize(
            width: CGFloat(cos(angle)) * radio,
            height: CGFloat(sin(angle)) * radio
        )
    }

    private func positionInUnion(setsContainingElement: [Int]) -> CGSize {
        let total = min(conjuntos.count, maxCircles)
        let angles = setsContainingElement.map { Double($0) * (2 * Double.pi / Double(total)) - Double.pi / 2 }
        
        let avgAngle = atan2(
            angles.map { sin($0) }.reduce(0, +) / Double(angles.count),
            angles.map { cos($0) }.reduce(0, +) / Double(angles.count))
        
        let distance = circleSize * 0.4
        
        return CGSize(
            width: CGFloat(cos(avgAngle)) * distance,
            height: CGFloat(sin(avgAngle)) * distance
        )
    }
    
    private func positionInIntersection() -> CGSize {
        return .zero
    }
    
    private func positionInDifference() -> CGSize {
        let total = min(conjuntos.count, maxCircles)
        let angle = -Double.pi / 2
        let distance = circleSize * 0.4
        
        return CGSize(
            width: CGFloat(cos(angle)) * distance,
            height: CGFloat(sin(angle)) * distance
        )
    }
    
    private func positionInComplement(elemento: String) -> CGSize {
        // Ubicación estable (no aleatoria) entre los elementos que sí forman parte del
        // complemento, para que no cambien de lugar cada vez que la vista se redibuja.
        let grupo = ordenarElementosConjunto(resultado)
        return posicionEnCirculo(elemento: elemento, grupo: grupo, distancia: circleSize * 0.95)
    }

    /// Distribuye de forma pareja y estable los elementos que no pertenecen a ningún
    /// conjunto ingresado, en un anillo fuera de los círculos.
    ///
    /// El contenedor del diagrama mide "circleSize * 2.2" de lado, así que su borde queda a
    /// "circleSize * 1.1" del centro. Usar esa misma distancia para el anillo (como se hacía
    /// antes) dejaba cada elemento (por ejemplo una "h" sola) exactamente ENCIMA del borde del
    /// recuadro, cortado a la mitad. Con "circleSize * 0.95" el anillo queda claramente dentro
    /// del recuadro y fuera de los círculos.
    private func posicionFueraDeConjuntos(elemento: String) -> CGSize {
        posicionEnCirculo(elemento: elemento, grupo: elementosFueraDeConjuntos, distancia: circleSize * 0.95)
    }

    /// Coloca "elemento" en un anillo de radio "distancia", repartiendo todos los elementos
    /// de "grupo" en ángulos iguales según su posición (ordenada) dentro del grupo.
    private func posicionEnCirculo(elemento: String, grupo: [String], distancia: CGFloat) -> CGSize {
        guard let idx = grupo.firstIndex(of: elemento) else { return .zero }
        let total = max(grupo.count, 1)
        let angle = (Double(idx) / Double(total)) * 2 * Double.pi
        return CGSize(
            width: CGFloat(cos(angle)) * distancia,
            height: CGFloat(sin(angle)) * distancia
        )
    }

    @ViewBuilder
    private func diagramaContradiccion() -> some View {
        // A ∩ ¬A = ∅ siempre: se muestra el conjunto A y su complemento ¬A como dos zonas
        // que nunca comparten elementos, con los elementos reales de A dentro del círculo
        // y los del complemento fuera, para dejar claro por qué la intersección es vacía.
        let circleSize1 = circleSize * 0.95
        let setA = conjuntos.first ?? []
        let complementoA = universo.subtracting(setA)
        let elementosDeA = ordenarElementosConjunto(setA)
        let elementosComplemento = ordenarElementosConjunto(elementosAMostrar.filter { complementoA.contains($0) })

        Circle()
            .stroke(colors[0], lineWidth: 2.5)
            .fill(colors[0].opacity(0.15))
            .frame(width: circleSize1, height: circleSize1)

        Circle()
            .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            .frame(width: circleSize * 1.9, height: circleSize * 1.9)

        ForEach(elementosDeA, id: \.self) { elemento in
            elementoView(elemento: elemento, destacado: false, enConjunto: true)
                .offset(posicionEnCirculo(elemento: elemento, grupo: elementosDeA, distancia: circleSize1 * 0.32))
        }

        ForEach(elementosComplemento, id: \.self) { elemento in
            elementoView(elemento: elemento, destacado: false, enConjunto: false)
                .offset(posicionEnCirculo(elemento: elemento, grupo: elementosComplemento, distancia: circleSize * 1.05))
        }

        Text("∅")
            .font(.system(size: elementFontSize * 1.6, weight: .bold))
            .foregroundColor(.red)
            .padding(6)
            .background(Circle().fill(Color.white))
            .offset(y: circleSize1 / 2 + 4)

        Text("A")
            .font(.system(size: elementFontSize + 2, weight: .bold))
            .foregroundColor(colors[0])
            .offset(y: -circleSize1 / 2 - 20)

        Text("¬A")
            .font(.system(size: elementFontSize + 2, weight: .bold))
            .foregroundColor(.red)
            .offset(y: circleSize * 1.9 / 2 + 16)
    }

    private func offsetForCircle(index: Int, total: Int) -> CGSize {
        guard total > 1 else { return .zero }
        
        let radius = circleSize / 2
        let angle = Double(index) * (2 * Double.pi / Double(total)) - Double.pi / 2
        
        return CGSize(
            width: CGFloat(cos(angle)) * radius * 0.8,
            height: CGFloat(sin(angle)) * radius * 0.8
        )
    }
    
    private func labelForSet(index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return index < letters.count ? letters[index] : "C\(index+1)"
    }
    
    private func labelOffsetForSet(index: Int, total: Int) -> CGSize {
        guard total > 1 else {
            return CGSize(width: 0, height: -circleSize/2 - 20)
        }

        let circleRadius = circleSize / 2
        let circleCenterDistance = circleRadius * 0.8
        let radius = circleCenterDistance + circleRadius + 15
        let angle = Double(index) * (2 * Double.pi / Double(total)) - Double.pi / 2

        return CGSize(
            width: CGFloat(cos(angle)) * radius,
            height: CGFloat(sin(angle)) * radius
        )
    }
}

struct EcuacionFormalView: View {
    let operacion: String
    let conjuntos: [String]
    
    var body: some View {
        VStack {
            Text("Ecuación Formal")
                .font(.headline)
                .padding(.bottom, 5)
            
            Text(ecuacionTexto())
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
    }
    
    func ecuacionTexto() -> String {
        switch operacion {
        case "Unión":
            if conjuntos.count >= 2 {
                return "A ∪ B = {x | x ∈ A ∨ x ∈ B} = \(conjuntos[0]) ∪ \(conjuntos[1])"
            } else {
                return "A ∪ B = {x | x ∈ A ∨ x ∈ B}"
            }
            
        case "Intersección":
            if conjuntos.count >= 2 {
                return "A ∩ B = {x | x ∈ A ∧ x ∈ B} = \(conjuntos[0]) ∩ \(conjuntos[1])"
            } else {
                return "A ∩ B = {x | x ∈ A ∧ x ∈ B}"
            }
            
        case "Diferencia":
            if conjuntos.count >= 2 {
                return "A ∖ B = {x | x ∈ A ∧ x ∉ B} = \(conjuntos[0]) ∖ \(conjuntos[1])"
            } else {
                return "A ∖ B = {x | x ∈ A ∧ x ∉ B}"
            }
            
        case "Complemento":
            if !conjuntos.isEmpty {
                return "A' = {x | x ∉ A ∧ x ∈ U} = \(conjuntos[0])'"
            } else {
                return "A' = {x | x ∉ A ∧ x ∈ U}"
            }
            
        case "Ley de Morgan 1":
            if conjuntos.count >= 2 {
                return "¬(A ∪ B) = ¬A ∩ ¬B = ¬(\(conjuntos[0]) ∪ \(conjuntos[1])) = ¬\(conjuntos[0]) ∩ ¬\(conjuntos[1])"
            } else {
                return "¬(A ∪ B) = ¬A ∩ ¬B"
            }
            
        case "Ley de Morgan 2":
            if conjuntos.count >= 2 {
                return "¬(A ∩ B) = ¬A ∪ ¬B = ¬(\(conjuntos[0]) ∩ \(conjuntos[1])) = ¬\(conjuntos[0]) ∪ ¬\(conjuntos[1])"
            } else {
                return "¬(A ∩ B) = ¬A ∪ ¬B"
            }
            
        case "Doble Negación":
            if !conjuntos.isEmpty {
                return "¬¬A = A = ¬¬\(conjuntos[0]) = \(conjuntos[0])"
            } else {
                return "¬¬A = A"
            }
            
        case "Conmutativa Unión":
            if conjuntos.count >= 2 {
                return "A ∪ B = B ∪ A = \(conjuntos[0]) ∪ \(conjuntos[1]) = \(conjuntos[1]) ∪ \(conjuntos[0])"
            } else {
                return "A ∪ B = B ∪ A"
            }
            
        case "Conmutativa Intersección":
            if conjuntos.count >= 2 {
                return "A ∩ B = B ∩ A = \(conjuntos[0]) ∩ \(conjuntos[1]) = \(conjuntos[1]) ∩ \(conjuntos[0])"
            } else {
                return "A ∩ B = B ∩ A"
            }
            
        case "Asociativa Unión":
            if conjuntos.count >= 3 {
                return "(A ∪ B) ∪ C = A ∪ (B ∪ C) = (\(conjuntos[0]) ∪ \(conjuntos[1])) ∪ \(conjuntos[2]) = \(conjuntos[0]) ∪ (\(conjuntos[1]) ∪ \(conjuntos[2]))"
            } else {
                return "(A ∪ B) ∪ C = A ∪ (B ∪ C)"
            }
            
        case "Asociativa Intersección":
            if conjuntos.count >= 3 {
                return "(A ∩ B) ∩ C = A ∩ (B ∩ C) = (\(conjuntos[0]) ∩ \(conjuntos[1])) ∩ \(conjuntos[2]) = \(conjuntos[0]) ∩ (\(conjuntos[1]) ∩ \(conjuntos[2]))"
            } else {
                return "(A ∩ B) ∩ C = A ∩ (B ∩ C)"
            }
            
        case "Idempotencia Unión":
            if !conjuntos.isEmpty {
                return "A ∪ A = A = \(conjuntos[0]) ∪ \(conjuntos[0]) = \(conjuntos[0])"
            } else {
                return "A ∪ A = A"
            }
            
        case "Idempotencia Intersección":
            if !conjuntos.isEmpty {
                return "A ∩ A = A = \(conjuntos[0]) ∩ \(conjuntos[0]) = \(conjuntos[0])"
            } else {
                return "A ∩ A = A"
            }
            
        case "Contradicción":
            if !conjuntos.isEmpty {
                return "A ∩ ¬A = ∅ = \(conjuntos[0]) ∩ ¬\(conjuntos[0]) = ∅"
            } else {
                return "A ∩ ¬A = ∅"
            }
            
        case "Distributiva Unión":
            if conjuntos.count >= 3 {
                return "A ∪ (B ∩ C) = (A ∪ B) ∩ (A ∪ C) = \(conjuntos[0]) ∪ (\(conjuntos[1]) ∩ \(conjuntos[2])) = (\(conjuntos[0]) ∪ \(conjuntos[1])) ∩ (\(conjuntos[0]) ∪ \(conjuntos[2]))"
            } else {
                return "A ∪ (B ∩ C) = (A ∪ B) ∩ (A ∪ C)"
            }
            
        case "Distributiva Intersección":
            if conjuntos.count >= 3 {
                return "A ∩ (B ∪ C) = (A ∩ B) ∪ (A ∩ C) = \(conjuntos[0]) ∩ (\(conjuntos[1]) ∪ \(conjuntos[2])) = (\(conjuntos[0]) ∩ \(conjuntos[1])) ∪ (\(conjuntos[0]) ∩ \(conjuntos[2]))"
            } else {
                return "A ∩ (B ∪ C) = (A ∩ B) ∪ (A ∩ C)"
            }
            
        default:
            return operacion
        }
    }
}

// MARK: - Preview
struct LogicaConjuntosView_Previews: PreviewProvider {
    static var previews: some View {
        LogicaConjuntosView()
    }
}
