// Carlos Angel Selvas Gomez.
import SwiftUI


// MARK: - Modelos de Datos

struct MovingImage {
    var id = UUID()
    var position: CGPoint
    var angle: Double
    var speed: Double
    var direction: CGPoint
}

struct Pregunta {
    let texto: String
    let opciones: [String]
    let respuestaCorrecta: Int
    let tema: String
}

// MARK: - Vistas de Componentes

struct MenuCard: View {
    let icon: String
    let title: String
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.white)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(width: 150, height: 150)
        .background(color.opacity(isAnimating ? 0.9 : 0.8))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(isAnimating ? 0.6 : 0.3), lineWidth: isAnimating ? 2 : 1)
        )
        .shadow(color: color.opacity(isAnimating ? 0.6 : 0.4), radius: isAnimating ? 15 : 10, x: 0, y: isAnimating ? 8 : 5)
        .scaleEffect(isAnimating ? 1.05 : 1.0)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever()) {
                isAnimating = true
            }
        }
    }
}

struct GameModalView: View {
    @Binding var mostrarJuego: Bool
    @Binding var mostrarEquipo: Bool
    @Binding var preguntaActual: Pregunta?
    @Binding var respuestaSeleccionada: Int?
    @Binding var mostrarRespuesta: Bool
    @Binding var puntaje: Int
    
    let preguntas: [Pregunta]
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: {
                    mostrarJuego = false
                    respuestaSeleccionada = nil
                    mostrarRespuesta = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            
            if mostrarEquipo {
                teamInfoView
            } else if let pregunta = preguntaActual {
                questionView(pregunta: pregunta)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
        .edgesIgnoringSafeArea(.all)
        .transition(.opacity)
        .onAppear {
            if preguntaActual == nil {
                mostrarEquipo = true
            }
        }
    }
    
    private var teamInfoView: some View {
        VStack(spacing: 15) {
            Text("Equipo de Desarrollo")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            Text("Carlos Angel Selvas Gomez")
                .foregroundColor(.white)
            
            Text("19270181")
                .foregroundColor(.white)
            
            Button(action: {
                mostrarEquipo = false
                generarNuevaPregunta()
            }) {
                Text("Comenzar Juego")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.7))
        .cornerRadius(15)
    }
    
    private func questionView(pregunta: Pregunta) -> some View {
        VStack(spacing: 15) {
            Text("Pregunta sobre \(pregunta.tema)")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(pregunta.texto)
                .font(.title3)
                .bold()
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.vertical, 10)
            
            ForEach(0..<pregunta.opciones.count, id: \.self) { index in
                Button(action: {
                    respuestaSeleccionada = index
                    verificarRespuesta()
                }) {
                    HStack {
                        Text(pregunta.opciones[index])
                            .foregroundColor(
                                mostrarRespuesta ?
                                (index == pregunta.respuestaCorrecta ? .green :
                                 (respuestaSeleccionada == index ? .red : .white)) : .white
                            )
                        Spacer()
                        if mostrarRespuesta && index == pregunta.respuestaCorrecta {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if mostrarRespuesta && respuestaSeleccionada == index && index != pregunta.respuestaCorrecta {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(
                        respuestaSeleccionada == index ?
                        Color.blue.opacity(0.3) : Color.white.opacity(0.1)
                    )
                    .cornerRadius(10)
                }
                .disabled(mostrarRespuesta)
            }
            
            if mostrarRespuesta {
                Button(action: {
                    generarNuevaPregunta()
                    respuestaSeleccionada = nil
                    mostrarRespuesta = false
                }) {
                    Text("Siguiente Pregunta")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
            
            Text("Puntaje: \(puntaje)")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 10)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.7))
        .cornerRadius(15)
    }
    
    private func generarNuevaPregunta() {
        preguntaActual = preguntas.randomElement()
    }
    
    private func verificarRespuesta() {
        guard let pregunta = preguntaActual,
              let respuesta = respuestaSeleccionada else { return }
        
        mostrarRespuesta = true
        
        if respuesta == pregunta.respuestaCorrecta {
            puntaje += 10
        }
    }
}

// MARK: - Vista Principal

struct ContentView: View {
    @State private var mostrarInstructivo = false
    @State private var movingImages: [MovingImage] = []
    @State private var animationTimer: Timer? = nil
    @State private var mostrarInformacion = false
    @State private var mostrarJuego = false
    @State private var preguntaActual: Pregunta?
    @State private var respuestaSeleccionada: Int?
    @State private var mostrarRespuesta = false
    @State private var puntaje = 0
    @State private var mostrarEquipo = false
    
    let preguntas: [Pregunta] = [
        // Preguntas originales (8)
        Pregunta(
            texto: "En lógica de conjuntos, ¿qué representa A ∪ B?",
            opciones: ["Intersección de A y B", "Unión de A y B", "Diferencia entre A y B", "Complemento de A"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Cuál es el resultado de ¬(P ∧ Q) en lógica proposicional?",
            opciones: ["¬P ∧ ¬Q", "¬P ∨ ¬Q", "P ∨ Q", "P ∧ Q"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "En lógica booleana, ¿qué representa A ⊕ B?",
            opciones: ["AND", "OR", "XOR", "NOT"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el complemento del conjunto universal?",
            opciones: ["El mismo conjunto universal", "El conjunto vacío", "Un conjunto unitario", "No existe"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "En lógica proposicional, ¿qué es una tautología?",
            opciones: ["Una proposición siempre falsa", "Una proposición siempre verdadera", "Una proposición contingente", "Una proposición indeterminada"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es el resultado de A ∧ 0 en lógica booleana?",
            opciones: ["A", "0", "1", "¬A"],
            respuestaCorrecta: 1,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "Si A = {1, 2, 3} y B = {3, 4, 5}, ¿qué es A ∩ B?",
            opciones: ["{1, 2, 3, 4, 5}", "{3}", "{1, 2, 4, 5}", "∅"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Qué ley lógica representa: ¬(P ∨ Q) ↔ (¬P ∧ ¬Q)?",
            opciones: ["Ley de De Morgan", "Ley distributiva", "Ley asociativa", "Ley conmutativa"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        
        // Lógica de Conjuntos (64 preguntas)
        Pregunta(
            texto: "¿Qué operación de conjuntos representa A - B?",
            opciones: ["Unión", "Intersección", "Diferencia", "Complemento"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A ⊆ B y B ⊆ A, entonces:",
            opciones: ["A = B", "A ∩ B = ∅", "A ∪ B = U", "A - B = B - A"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El conjunto potencia de {a, b} es:",
            opciones: ["{∅, {a}, {b}}", "{∅, {a}, {b}, {a, b}}", "{{a}, {b}}", "{{a}, {b}, {a, b}}"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Cuál es la cardinalidad del conjunto {1, 2, 3, 4, 5}?",
            opciones: ["4", "5", "6", "10"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {x | x es par} y B = {x | x es impar}, entonces A ∩ B =",
            opciones: ["U", "∅", "A", "B"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La propiedad A ∪ (B ∩ C) = (A ∪ B) ∩ (A ∪ C) es:",
            opciones: ["Ley distributiva", "Ley conmutativa", "Ley asociativa", "Ley de absorción"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Qué representa el símbolo ∅ en teoría de conjuntos?",
            opciones: ["Conjunto universal", "Conjunto unitario", "Conjunto vacío", "Conjunto infinito"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {1, 2} y B = {2, 3}, entonces A × B contiene:",
            opciones: ["2 elementos", "3 elementos", "4 elementos", "6 elementos"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La diferencia simétrica A Δ B es igual a:",
            opciones: ["(A - B) ∪ (B - A)", "(A ∪ B) - (A ∩ B)", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Cuál de estos es un conjunto infinito?",
            opciones: ["{1, 2, 3}", "∅", "N (números naturales)", "Conjunto potencia de {a, b}"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A tiene 3 elementos, ¿cuántos elementos tiene P(A)?",
            opciones: ["3", "6", "8", "9"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La ley de De Morgan para conjuntos establece que:",
            opciones: ["A ∪ B = B ∪ A", "A ∩ (B ∪ C) = (A ∩ B) ∪ (A ∩ C)", "(A ∪ B)' = A' ∩ B'", "A ∪ ∅ = A"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Qué significa que dos conjuntos sean disjuntos?",
            opciones: ["Que son iguales", "Que su unión es el conjunto universal", "Que su intersección es vacía", "Que uno es subconjunto del otro"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El complemento del conjunto vacío is:",
            opciones: ["El conjunto vacío", "El conjunto universal", "Un conjunto unitario", "No existe"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {1, 2, 3} y B = {3, 4, 5}, ¿cuál es A Δ B?",
            opciones: ["{3}", "{1, 2, 4, 5}", "{1, 2, 3, 4, 5}", "∅"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La propiedad A ∩ (B ∪ C) = (A ∩ B) ∪ (A ∩ C) es:",
            opciones: ["Ley distributiva", "Ley conmutativa", "Ley asociativa", "Ley de identidad"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Qué representa |A| en teoría de conjuntos?",
            opciones: ["Complemento de A", "Conjunto potencia de A", "Cardinalidad de A", "Producto cartesiano de A"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A ⊆ B, entonces A ∩ B =",
            opciones: ["A", "B", "∅", "U"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El conjunto {x | x ∈ ℝ y x² = -1} es:",
            opciones: ["Unitario", "Vacío", "Infinito", "Universal"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {a, b} y B = {1, 2}, ¿cuántos elementos tiene A × B?",
            opciones: ["2", "3", "4", "6"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La ley A ∪ A' = U se conoce como:",
            opciones: ["Ley de complemento", "Ley de identidad", "Ley de idempotencia", "Ley de dominación"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Cuál de estos conjuntos es numerable?",
            opciones: ["Números naturales", "Números reales", "Conjunto potencia de los naturales", "Números irracionales"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A y B son conjuntos finitos, |A ∪ B| = |A| + |B| - |A ∩ B| es:",
            opciones: ["Principio de inclusión-exclusión", "Principio del palomar", "Principio de multiplicación", "Principio de adición"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El conjunto de todos los subconjuntos de un conjunto se llama:",
            opciones: ["Conjunto universal", "Conjunto potencia", "Conjunto producto", "Conjunto complemento"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = ∅, entonces P(A) =",
            opciones: ["∅", "{∅}", "A", "U"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La operación A ∩ U = A representa la:",
            opciones: ["Ley de identidad", "Ley de dominación", "Ley de idempotencia", "Ley de complemento"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Qué es una partición de un conjunto?",
            opciones: ["Un subconjunto propio", "Una colección de subconjuntos disjuntos cuya unión es el conjunto", "El complemento del conjunto", "El producto cartesiano consigo mismo"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {1, 2} y B = {2, 3}, entonces A - B =",
            opciones: ["{1}", "{2}", "{3}", "{1, 3}"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La propiedad A ∪ B = B ∪ A es:",
            opciones: ["Ley conmutativa", "Ley asociativa", "Ley distributiva", "Ley de absorción"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El conjunto {x | x es divisor de 12} es:",
            opciones: ["Infinito", "Finito", "Vacío", "Unitario"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A ⊆ B, entonces A ∪ B =",
            opciones: ["A", "B", "∅", "U"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La diferencia A - B es igual a:",
            opciones: ["A ∩ B'", "B ∩ A'", "A' ∩ B", "A' ∪ B"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Cuál es la cardinalidad del conjunto vacío?",
            opciones: ["0", "1", "No está definida", "Depende del contexto"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {1, 2, 3} y B = {4, 5, 6}, entonces A ∩ B =",
            opciones: ["∅", "{1, 2, 3, 4, 5, 6}", "{1, 2, 3}", "{4, 5, 6}"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La ley A ∪ ∅ = A es:",
            opciones: ["Ley de identidad", "Ley de dominación", "Ley de idempotencia", "Ley de complemento"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El conjunto de números primos es:",
            opciones: ["Finito", "Infinito", "Vacío", "Unitario"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {a, b, c}, ¿cuántos elementos tiene P(P(A))?",
            opciones: ["8", "16", "256", "512"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La propiedad A ∩ (B ∩ C) = (A ∩ B) ∩ C es:",
            opciones: ["Ley asociativa", "Ley conmutativa", "Ley distributiva", "Ley de absorción"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Qué significa que un conjunto sea countable?",
            opciones: ["Que tiene n elementos", "Que es finito", "Que se puede poner en correspondencia biyectiva con los naturales", "Que es subconjunto de los reales"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {1, 2} y B = {2, 3}, entonces (A ∩ B) × {0} =",
            opciones: ["∅", "{(2, 0)}", "{(1, 0), (2, 0)}", "{(2, 0), (3, 0)}"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La ley A ∩ A' = ∅ es:",
            opciones: ["Ley de complemento", "Ley de identidad", "Ley de idempotencia", "Ley de dominación"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El conjunto {x ∈ ℤ | -2 < x < 3} es:",
            opciones: ["{-1, 0, 1, 2}", "{-2, -1, 0, 1, 2}", "{-1, 0, 1, 2, 3}", "{-2, -1, 0, 1, 2, 3}"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A y B son conjuntos, A × B = B × A si y solo si:",
            opciones: ["A = B", "A = ∅ o B = ∅", "A ⊆ B", "B ⊆ A"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La propiedad A ∪ (A ∩ B) = A is:",
            opciones: ["Ley de absorción", "Ley de idempotencia", "Ley distributiva", "Ley de complemento"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Cuál de estos conjuntos es incontable?",
            opciones: ["Números racionales", "Números enteros", "Números reales", "Números naturales"],
            respuestaCorrecta: 3,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {1, 2} y B = {a, b}, entonces A × B =",
            opciones: ["{(1,a), (1,b), (2,a), (2,b)}", "{(a,1), (a,2), (b,1), (b,2)}", "{(1,2), (a,b)}", "{(1,a), (2,b)}"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La ley A ∩ ∅ = ∅ es:",
            opciones: ["Ley de dominación", "Ley de identidad", "Ley de idempotencia", "Ley de complemento"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El conjunto de soluciones de x² = 4 en ℝ es:",
            opciones: ["{-2, 2}", "{2}", "{-4, 4}", "{4}"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si |A| = 5 and |B| = 3, entonces |A × B| =",
            opciones: ["8", "15", "125", "243"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La propiedad A ∪ A = A es:",
            opciones: ["Ley de idempotencia", "Ley de identidad", "Ley de complemento", "Ley de dominación"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Qué es una relación de equivalencia?",
            opciones: ["Una relación reflexiva, simétrica y transitiva", "Una relación antisimétrica y transitiva", "Una relación total y conexa", "Una relación irreflexiva y asimétrica"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {x | x es múltiplo de 2} y B = {x | x es múltiplo de 3}, entonces A ∩ B son los múltiplos de:",
            opciones: ["2", "3", "5", "6"],
            respuestaCorrecta: 3,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La ley (A')' = A es:",
            opciones: ["Ley de doble complemento", "Ley de identidad", "Ley de idempotencia", "Ley de dominación"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El conjunto {∅} es:",
            opciones: ["Vacío", "Unitario", "Infinito", "Universal"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si R es una relación de equivalencia en A, las clases de equivalencia:",
            opciones: ["Forman una partición de A", "Son subconjuntos disjuntos de A", "Su unión es A", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La propiedad A ∩ (B ∪ A) = A es:",
            opciones: ["Ley de absorción", "Ley de idempotencia", "Ley distributiva", "Ley de complemento"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "¿Cuál de estos es un conjunto bien ordenado?",
            opciones: ["Números reales", "Números racionales", "Números naturales", "Números irracionales"],
            respuestaCorrecta: 2,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {1, 2, 3} y B = {2, 3, 4}, entonces (A - B) ∪ (B - A) =",
            opciones: ["{1, 4}", "{2, 3}", "{1, 2, 3, 4}", "∅"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La ley A ∪ (B ∪ C) = (A ∪ B) ∪ C es:",
            opciones: ["Ley asociativa", "Ley conmutativa", "Ley distributiva", "Ley de absorción"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El axioma de elección establece que:",
            opciones: ["Todo conjunto tiene un buen orden", "Para toda familia de conjuntos no vacíos, existe una función de elección", "El conjunto de todos los conjuntos existe", "No existen conjuntos incontables"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "Si A = {a, b} y B = {1}, entonces B × A =",
            opciones: ["{(1,a), (1,b)}", "{(a,1), (b,1)}", "{1}", "{(a,b)}"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "La propiedad A ⊆ B si y solo si A ∪ B = B es:",
            opciones: ["Verdadera", "Falsa", "Solo si A ≠ ∅", "Solo si B ≠ ∅"],
            respuestaCorrecta: 0,
            tema: "Lógica de Conjuntos"
        ),
        Pregunta(
            texto: "El conjunto de todos los números algebraicos es:",
            opciones: ["Finito", "Countable", "Uncountable", "Vacío"],
            respuestaCorrecta: 1,
            tema: "Lógica de Conjuntos"
        ),
        
        // Lógica Proposicional (64 preguntas)
        Pregunta(
            texto: "¿Cuál es la negación de 'Si llueve, entonces me mojo'?",
            opciones: ["Llueve y no me mojo", "No llueve y me mojo", "Si no llueve, no me mojo", "Llueve o me mojo"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula P → Q es equivalente a:",
            opciones: ["¬P ∨ Q", "P ∨ ¬Q", "¬P → ¬Q", "Q → P"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué conectivo lógico representa 'pero' en español?",
            opciones: ["∧", "∨", "→", "¬"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La contrapositiva de P → Q es:",
            opciones: ["Q → P", "¬Q → ¬P", "¬P → ¬Q", "P ∧ ¬Q"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la inversa de 'Si estudio, entonces apruebo'?",
            opciones: ["Si no estudio, entonces no apruebo", "Si apruebo, entonces estudio", "Estudio y no apruebo", "Si no apruebo, entonces no estudio"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula ¬(P ∧ Q) es equivalente a:",
            opciones: ["¬P ∧ ¬Q", "¬P ∨ ¬Q", "P ∨ Q", "P ∧ Q"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "Una contradicción es una fórmula que:",
            opciones: ["Siempre es verdadera", "Siempre es falsa", "A veces verdadera, a veces falsa", "No se puede evaluar"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "El modus ponens establece que:",
            opciones: ["De P → Q y Q, se infiere P", "De P → Q y ¬Q, se infiere ¬P", "De P → Q y P, se infiere Q", "De P ∨ Q y ¬P, se infiere Q"],
            respuestaCorrecta: 2,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la recíproca de 'Si hace sol, vamos a la playa'?",
            opciones: ["Si no hace sol, no vamos a la playa", "Si vamos a la playa, entonces hace sol", "Hace sol y no vamos a la playa", "No hace sol o vamos a la playa"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula P ↔ Q es equivalente a:",
            opciones: ["(P → Q) ∧ (Q → P)", "(P → Q) ∨ (Q → P)", "P ∧ Q", "P ∨ Q"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "El silogismo hipotético establece que:",
            opciones: ["De P → Q y Q → R, se infiere P → R", "De P → Q y P, se infiere Q", "De P ∨ Q y ¬P, se infiere Q", "De P → Q y ¬Q, se infiere ¬P"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la negación de 'Todos los hombres son mortales'?",
            opciones: ["Ningún hombre es mortal", "Algún hombre no es mortal", "Algún hombre es mortal", "Todos los hombres son inmortales"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La ley de doble negación establece que:",
            opciones: ["¬¬P ≡ P", "P ∧ ¬P ≡ F", "P ∨ ¬P ≡ V", "P → P ≡ V"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué conectivo lógico tiene la tabla de verdad: V F F V?",
            opciones: ["∧", "∨", "→", "↔"],
            respuestaCorrecta: 3,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "El modus tollens establece que:",
            opciones: ["De P → Q y Q, se infiere P", "De P → Q y ¬Q, se infiere ¬P", "De P → Q y P, se infiere Q", "De P ∨ Q y ¬P, se infiere Q"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la negación de 'Ningún estudiante aprobó'?",
            opciones: ["Todos los estudiantes aprobaron", "Algún estudiante aprobó", "Algún estudiante no aprobó", "Ningún estudiante reprobó"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula P ∨ (Q ∧ R) es equivalente a:",
            opciones: ["(P ∨ Q) ∧ (P ∨ R)", "(P ∧ Q) ∨ (P ∧ R)", "P ∧ (Q ∨ R)", "P ∨ Q ∨ R"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué significa que un argumento sea válido?",
            opciones: ["Las premisas son verdaderas", "La conclusión es verdadera", "Si las premisas son verdaderas, la conclusión debe ser verdadera", "Las premisas y conclusión son verdaderas"],
            respuestaCorrecta: 2,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula ¬(P → Q) es equivalente a:",
            opciones: ["P ∧ ¬Q", "¬P ∧ Q", "P → ¬Q", "¬P → Q"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la contrapositiva de 'Si es un triángulo, entonces tiene tres lados'?",
            opciones: ["Si no es un triángulo, entonces no tiene tres lados", "Si tiene tres lados, entonces es un triángulo", "Si no tiene tres lados, entonces no es un triángulo", "Es un triángulo y no tiene tres lados"],
            respuestaCorrecta: 2,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La ley de identidad establece que:",
            opciones: ["P ∧ P ≡ P", "P ∨ P ≡ P", "P → P ≡ V", "P ↔ P ≡ V"],
            respuestaCorrecta: 2,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué conectivo lógico tiene la tabla de verdad: V V V F?",
            opciones: ["∧", "∨", "→", "↔"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula (P → Q) ∧ (Q → P) es equivalente a:",
            opciones: ["P ↔ Q", "P ∧ Q", "P ∨ Q", "P → Q"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la negación de 'Algunos pájaros vuelan'?",
            opciones: ["Todos los pájaros vuelan", "Ningún pájaro vuela", "Algunos pájaros no vuelan", "Todos los pájaros no vuelan"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "El dilema constructivo establece que:",
            opciones: ["De P → Q y R → S y P ∨ R, se infiere Q ∨ S", "De P → Q y Q → R, se infiere P → R", "De P ∨ Q y ¬P, se infiere Q", "De P → Q y ¬Q, se infiere ¬P"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula P → (Q → R) es equivalente a:",
            opciones: ["(P ∧ Q) → R", "(P ∨ Q) → R", "P → Q ∧ R", "P → Q ∨ R"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué significa que dos fórmulas sean lógicamente equivalentes?",
            opciones: ["Tienen las mismas variables", "Tienen la misma tabla de verdad", "Ambas son tautologías", "Ambas son contradicciones"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula ¬(P ↔ Q) es equivalente a:",
            opciones: ["P ↔ ¬Q", "¬P ↔ Q", "P ⊕ Q", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la forma normal conjuntiva de P ↔ Q?",
            opciones: ["(P ∨ ¬Q) ∧ (¬P ∨ Q)", "(P ∧ Q) ∨ (¬P ∧ ¬Q)", "(P ∨ Q) ∧ (¬P ∨ ¬Q)", "(P ∧ ¬Q) ∨ (¬P ∧ Q)"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "El principio de no contradicción establece que:",
            opciones: ["P ∨ ¬P ≡ V", "P ∧ ¬P ≡ F", "P → P ≡ V", "P ↔ P ≡ V"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué conectivo lógico tiene la tabla de verdad: V F V V?",
            opciones: ["∧", "∨", "→", "↔"],
            respuestaCorrecta: 2,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula (P ∧ Q) → R es equivalente a:",
            opciones: ["P → (Q → R)", "P ∨ Q → R", "P → Q ∧ R", "P → Q ∨ R"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la negación de 'Siempre que llueve, me mojo'?",
            opciones: ["Nunca que llueve me mojo", "A veces cuando llueve no me mojo", "Siempre que no llueve no me mojo", "Me mojo aunque no llueva"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La ley de absorción establece que:",
            opciones: ["P ∨ (P ∧ Q) ≡ P", "P ∧ (P ∨ Q) ≡ P", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué es un literal en lógica proposicional?",
            opciones: ["Una variable proposicional", "Una variable o su negación", "Una conjunción de variables", "Una disyunción de variables"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula P ∨ ¬P es:",
            opciones: ["Una tautología", "Una contradicción", "Una contingencia", "Una equivalencia"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la forma normal disyuntiva de P → Q?",
            opciones: ["¬P ∨ Q", "P ∧ ¬Q", "P ∨ Q", "¬P ∧ Q"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "El silogismo disyuntivo establece que:",
            opciones: ["De P ∨ Q y ¬P, se infiere Q", "De P → Q y Q → R, se infiere P → R", "De P → Q y P, se infiere Q", "De P → Q y ¬Q, se infiere ¬P"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula ¬(P ∨ Q) es equivalente a:",
            opciones: ["¬P ∧ ¬Q", "¬P ∨ ¬Q", "P ∧ Q", "P ∨ Q"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la negación de 'Juan es alto y María es inteligente'?",
            opciones: ["Juan no es alto y María no es inteligente", "Juan no es alto o María no es inteligente", "Si Juan es alto, entonces María no es inteligente", "Juan es alto o María es inteligente"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La ley de exportación establece que:",
            opciones: ["(P ∧ Q) → R ≡ P → (Q → R)", "P → (Q ∧ R) ≡ (P → Q) ∧ (P → R)", "P → (Q ∨ R) ≡ (P → Q) ∨ (P → R)", "P ∨ (Q ∧ R) ≡ (P ∨ Q) ∧ (P ∨ R)"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué es una cláusula de Horn?",
            opciones: ["Una disyunción con a lo sumo un literal positivo", "Una conjunción de literales", "Una implicación con premisas conjuntivas", "Una equivalencia entre dos fórmulas"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula P ∧ ¬P es:",
            opciones: ["Una tautología", "Una contradicción", "Una contingencia", "Una equivalencia"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la recíproca de 'Si es un cuadrado, entonces tiene cuatro lados'?",
            opciones: ["Si no es un cuadrado, entonces no tiene cuatro lados", "Si tiene cuatro lados, entonces es un cuadrado", "Si no tiene cuatro lados, entonces no es un cuadrado", "Es un cuadrado y no tiene cuatro lados"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La ley de contraposición establece que:",
            opciones: ["P → Q ≡ ¬Q → ¬P", "P → Q ≡ Q → P", "P → Q ≡ ¬P → ¬Q", "P → Q ≡ P ∧ ¬Q"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué es un modelo para una fórmula proposicional?",
            opciones: ["Una interpretación que la hace verdadera", "Una interpretación que la hace falsa", "Una variable de la fórmula", "Una conectivo de la fórmula"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula (P → Q) ∨ (Q → P) es:",
            opciones: ["Una tautología", "Una contradicción", "Una contingencia", "Una equivalencia"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la negación de 'Ningún gato tiene cola'?",
            opciones: ["Todos los gatos tienen cola", "Algún gato tiene cola", "Algún gato no tiene cola", "Todos los gatos no tienen cola"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La ley de idempotencia establece que:",
            opciones: ["P ∧ P ≡ P", "P ∨ P ≡ P", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué es una fórmula satisfacible?",
            opciones: ["Una tautología", "Una contradicción", "Que tiene al menos un modelo", "Que no tiene modelos"],
            respuestaCorrecta: 2,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula P → (Q → P) es:",
            opciones: ["Una tautología", "Una contradicción", "Una contingencia", "Una equivalencia"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la forma prenexa de ∀xP(x) ∧ ∃yQ(y)?",
            opciones: ["∀x∃y(P(x) ∧ Q(y))", "∃y∀x(P(x) ∧ Q(y))", "∀x(P(x) ∧ ∃yQ(y))", "∃y(∀xP(x) ∧ Q(y))"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "El principio de explosión establece que:",
            opciones: ["De una contradicción se puede derivar cualquier fórmula", "De una tautología se puede derivar cualquier fórmula", "Toda fórmula tiene un modelo", "Ninguna fórmula es both satisfacible e insatisfacible"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula ¬P → (P → Q) es:",
            opciones: ["Una tautología", "Una contradicción", "Una contingencia", "Una equivalencia"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la negación de 'Siempre que estudio, aprendo'?",
            opciones: ["Nunca cuando estudio aprendo", "A veces estudio y no aprendo", "Siempre que no estudio no aprendo", "Aprendo aunque no estudie"],
            respuestaCorrecta: 1,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La ley de equivalencia material establece que:",
            opciones: ["P ↔ Q ≡ (P → Q) ∧ (Q → P)", "P → Q ≡ ¬P ∨ Q", "P ∧ Q ≡ ¬(¬P ∨ ¬Q)", "P ∨ Q ≡ ¬(¬P ∧ ¬Q)"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Qué es un resolvente en resolución proposicional?",
            opciones: ["La cláusula resultante de aplicar resolución a dos cláusulas", "Una cláusula unitaria", "Una cláusula vacía", "Una cláusula de Horn"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "La fórmula (P → Q) → (¬Q → ¬P) es:",
            opciones: ["Una tautología", "Una contradicción", "Una contingencia", "Una equivalencia"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "¿Cuál es la forma clausal de P ∧ (Q ∨ R)?",
            opciones: ["{P}, {Q, R}", "{P, Q, R}", "{P, Q}, {P, R}", "{P}, {Q}, {R}"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        Pregunta(
            texto: "El teorema de completitud de la lógica proposicional establece que:",
            opciones: ["Toda tautología es demostrable", "Toda fórmula demostrable es una tautología", "Toda fórmula tiene un modelo", "Toda fórmula es o satisfacible o refutable"],
            respuestaCorrecta: 0,
            tema: "Lógica Proposicional"
        ),
        
        // Lógica Booleana (64 preguntas)
        Pregunta(
            texto: "¿Cuál es la tabla de verdad de la operación AND?",
            opciones: ["1 1=1, 1 0=0, 0 1=0, 0 0=0", "1 1=1, 1 0=1, 0 1=1, 0 0=0", "1 1=0, 1 0=1, 0 1=1, 0 0=1", "1 1=1, 1 0=0, 0 1=0, 0 0=1"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de identidad en álgebra booleana establece que:",
            opciones: ["A + 0 = A", "A · 1 = A", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el complemento de 1 en álgebra booleana?",
            opciones: ["0", "1", "A", "A'"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación NAND es equivalente a:",
            opciones: ["NOT(AND(A, B))", "OR(NOT(A), NOT(B))", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es la tabla de verdad de la operación XOR?",
            opciones: ["1 1=0, 1 0=1, 0 1=1, 0 0=0", "1 1=1, 1 0=0, 0 1=0, 0 0=1", "1 1=0, 1 0=0, 0 1=0, 0 0=0", "1 1=1, 1 0=1, 0 1=1, 0 0=0"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de dominación establece que:",
            opciones: ["A + 1 = 1", "A · 0 = 0", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el dual de A + B = B + A?",
            opciones: ["A · B = B · A", "A + B = A · B", "A · B = A + B", "A + 0 = A"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación NOR es equivalente to:",
            opciones: ["NOT(OR(A, B))", "AND(NOT(A), NOT(B))", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es la forma canónica de una función booleana?",
            opciones: ["Suma de productos o producto de sumas", "Solo suma de productos", "Solo producto de sumas", "Ninguna de las anteriores"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de absorción establece que:",
            opciones: ["A + A·B = A", "A·(A + B) = A", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el complemento de A en álgebra booleana?",
            opciones: ["A'", "1", "0", "B"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de De Morgan para álgebra booleana establece que:",
            opciones: ["(A + B)' = A' · B'", "(A · B)' = A' + B'", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es la tabla de verdad de la operación XNOR?",
            opciones: ["1 1=1, 1 0=0, 0 1=0, 0 0=1", "1 1=0, 1 0=1, 0 1=1, 0 0=0", "1 1=1, 1 0=0, 0 1=0, 0 0=0", "1 1=0, 1 0=0, 0 1=0, 0 0=1"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de idempotencia establece que:",
            opciones: ["A + A = A", "A · A = A", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es un minitérmino en álgebra booleana?",
            opciones: ["Un producto que incluye todas las variables", "Una suma que incluye todas las variables", "Un producto que incluye algunas variables", "Una suma que incluye algunas variables"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de conmutatividad establece que:",
            opciones: ["A + B = B + A", "A · B = B · A", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el elemento neutro de la operación AND?",
            opciones: ["1", "0", "A", "A'"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de asociatividad establece que:",
            opciones: ["A + (B + C) = (A + B) + C", "A · (B · C) = (A · B) · C", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es un maxitérmino en álgebra booleana?",
            opciones: ["Una suma que incluye todas las variables", "Un producto que incluye todas las variables", "Una suma que incluye algunas variables", "Un producto que incluye algunas variables"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de distributividad establece que:",
            opciones: ["A · (B + C) = A·B + A·C", "A + B·C = (A + B)·(A + C)", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el elemento absorbente de la operación OR?",
            opciones: ["1", "0", "A", "A'"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación IMPLIES (A → B) es equivalente a:",
            opciones: ["A' + B", "A + B'", "A · B", "A' · B'"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es un mapa de Karnaugh?",
            opciones: ["Una herramienta para simplificar funciones booleanas", "Una representación tabular de funciones booleanas", "Un método para encontrar minitérminos", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de involución establece que:",
            opciones: ["(A')' = A", "A + A' = 1", "A · A' = 0", "A + 0 = A"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el dual de A · (B + C) = A·B + A·C?",
            opciones: ["A + B·C = (A + B)·(A + C)", "A · B = B · A", "A + 0 = A", "A · 1 = A"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación EQUIVALENCE (A ↔ B) es equivalente a:",
            opciones: ["A·B + A'·B'", "A·B' + A'·B", "A + B", "A · B"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es un circuito combinacional?",
            opciones: ["Un circuito cuya salida depende solo de las entradas actuales", "Un circuito con memoria", "Un circuito con realimentación", "Un circuito secuencial"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley del complemento establece que:",
            opciones: ["A + A' = 1", "A · A' = 0", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es la forma normal disyuntiva (DNF) de una función booleana?",
            opciones: ["Suma de minitérminos", "Producto de maxitérminos", "Suma de maxitérminos", "Producto de minitérminos"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación NOT es:",
            opciones: ["Unaria", "Binaria", "Ternaria", "Cuaternaria"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es un half-adder?",
            opciones: ["Un circuito que suma dos bits y produce suma y carry", "Un circuito que suma tres bits", "Un circuito que resta dos bits", "Un circuito que multiplica dos bits"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de consenso establece que:",
            opciones: ["A·B + A'·C + B·C = A·B + A'·C", "(A + B)·(A' + C)·(B + C) = (A + B)·(A' + C)", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es la forma normal conjuntiva (CNF) de una función booleana?",
            opciones: ["Producto de maxitérminos", "Suma de minitérminos", "Producto de minitérminos", "Suma de maxitérminos"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación AND es:",
            opciones: ["Conmutativa", "Asociativa", "Idempotente", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es un full-adder?",
            opciones: ["Un circuito que suma tres bits y produce suma y carry", "Un circuito que suma dos bits", "Un circuito que resta dos bits", "Un circuito que multiplica dos bits"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de dualidad establece que:",
            opciones: ["Cada teorema tiene su dual", "Intercambiando 0 y 1, y + y ·", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el principio de funcionamiento de un multiplexor?",
            opciones: ["Selecciona una de varias entradas según líneas de control", "Combina varias entradas en una salida", "Distribuye una entrada a varias salidas", "Almacena un bit de información"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación OR es:",
            opciones: ["Conmutativa", "Asociativa", "Idempotente", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es un decodificador?",
            opciones: ["Convierte un código de entrada en una línea de salida activa", "Selecciona una de varias entradas", "Combina varias entradas", "Almacena información"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de redundancia establece que:",
            opciones: ["A + A·B = A", "A·(A + B) = A", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es la función de un flip-flop?",
            opciones: ["Almacenar un bit de información", "Sumar dos bits", "Multiplicar dos bits", "Seleccionar entradas"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación NAND es:",
            opciones: ["Conmutativa", "No asociativa", "Universal", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es un circuito secuencial?",
            opciones: ["Un circuito cuya salida depende de entradas actuales y pasadas", "Un circuito sin memoria", "Un circuito combinacional", "Un circuito con solo compuertas básicas"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de complemento dual establece que:",
            opciones: ["A + A' = 1", "A · A' = 0", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es la función principal de un contador?",
            opciones: ["Generar una secuencia de estados", "Almacenar datos", "Sumar números", "Multiplicar números"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación NOR es:",
            opciones: ["Conmutativa", "No asociativa", "Universal", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es un registro de desplazamiento?",
            opciones: ["Un circuito que almacena y desplaza bits", "Un circuito que suma bits", "Un circuito que decodifica", "Un circuito multiplexor"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de idempotencia dual establece que:",
            opciones: ["A + A = A", "A · A = A", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el propósito de la simplificación de funciones booleanas?",
            opciones: ["Reducir el número de compuertas", "Mejorar el rendimiento", "Disminuir el costo", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación XOR es:",
            opciones: ["Conmutativa", "Asociativa", "No idempotente", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es una máquina de estados finitos?",
            opciones: ["Un modelo abstracto de computación con estados finitos", "Un circuito combinacional", "Un tipo de memoria", "Un dispositivo de entrada/salida"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de absorción dual establece que:",
            opciones: ["A + A·B = A", "A·(A + B) = A", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es la diferencia entre lógica positiva y negativa?",
            opciones: ["La asignación de voltajes a valores lógicos", "El tipo de compuertas utilizadas", "La velocidad de operación", "El número de entradas"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación XNOR es:",
            opciones: ["Conmutativa", "Asociativa", "Idempotente", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es el álgebra de Boole?",
            opciones: ["Una estructura algebraica que captura las propiedades de operaciones lógicas", "Un tipo de circuito", "Un método de simplificación", "Un lenguaje de programación"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de De Morgan dual establece que:",
            opciones: ["(A + B)' = A' · B'", "(A · B)' = A' + B'", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el teorema de expansión de Shannon?",
            opciones: ["F(x₁,...,xₙ) = xᵢ·F(xᵢ=1) + xᵢ'·F(xᵢ=0)", "F(x₁,...,xₙ) = (xᵢ + F(xᵢ=0))·(xᵢ' + F(xᵢ=1))", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación IMPLIES es:",
            opciones: ["No conmutativa", "No asociativa", "No idempotente", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es un circuito aritmético-lógico (ALU)?",
            opciones: ["Un circuito que realiza operaciones aritméticas y lógicas", "Un tipo de memoria", "Un dispositivo de entrada", "Un decodificador"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de consenso dual establece que:",
            opciones: ["A·B + A'·C + B·C = A·B + A'·C", "(A + B)·(A' + C)·(B + C) = (A + B)·(A' + C)", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el principio de dualidad en álgebra de Boole?",
            opciones: ["Intercambiar AND y OR, y 0 y 1", "Intercambiar variables y complementos", "Intercambiar entradas y salidas", "Intercambiar circuits serie y paralelo"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación EQUIVALENCE es:",
            opciones: ["Conmutativa", "Asociativa", "Idempotente", "Todas las anteriores"],
            respuestaCorrecta: 3,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es la hazard en circuitos digitales?",
            opciones: ["Un glitch o pulso no deseado", "Un tipo de compuerta", "Un método de simplificación", "Un tipo de memoria"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de involución dual establece que:",
            opciones: ["(A')' = A", "A + A' = 1", "A · A' = 0", "A + 0 = A"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es el propósito de los mapas de Karnaugh?",
            opciones: ["Simplificar funciones booleanas visualmente", "Representar tablas de verdad", "Diseñar circuitos secuenciales", "Analizar hazards"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La operación NAND es funcionalmente completa porque:",
            opciones: ["Puede implementar AND, OR, NOT", "Puede implementar cualquier función booleana", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Qué es la metaestabilidad en circuitos digitales?",
            opciones: ["Un estado indeterminado que puede persistir", "Un tipo de hazard", "Un método de sincronización", "Un tipo de memoria"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "La ley de complemento para constantes establece que:",
            opciones: ["0' = 1", "1' = 0", "Ambas son correctas", "Ninguna es correcta"],
            respuestaCorrecta: 2,
            tema: "Lógica Booleana"
        ),
        Pregunta(
            texto: "¿Cuál es la diferencia entre lógica combinacional y secuencial?",
            opciones: ["La secuencial tiene memoria, la combinacional no", "La combinacional es más rápida", "La secuencial tiene menos compuertas", "La combinacional tiene más estados"],
            respuestaCorrecta: 0,
            tema: "Lógica Booleana"
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Fondo con imagen de ajedrez
                Image("ajedrez")
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.3))
                    .edgesIgnoringSafeArea(.all)
                
                // Varias imágenes animadas
                ForEach(movingImages, id: \.id) { image in
                    Image("pieza")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(image.angle))
                        .position(image.position)
                }
                
                // Contenido principal
                mainContentView
            }
            .onAppear {
                setupMovingImages()
                startAnimationTimer()
            }
            .onShake {
                mostrarJuego = true
                if preguntaActual == nil {
                    preguntaActual = preguntas.randomElement()
                }
            }
            .overlay(
                Group {
                    if mostrarInstructivo {
                        InstructivoView(mostrarInstructivo: $mostrarInstructivo)
                    }
                    
                    if mostrarInformacion {
                        InformacionAlumnoView(mostrarInformacion: $mostrarInformacion)
                    }
                    
                    if mostrarJuego {
                        GameModalView(
                            mostrarJuego: $mostrarJuego,
                            mostrarEquipo: $mostrarEquipo,
                            preguntaActual: $preguntaActual,
                            respuestaSeleccionada: $respuestaSeleccionada,
                            mostrarRespuesta: $mostrarRespuesta,
                            puntaje: $puntaje,
                            preguntas: preguntas
                        )
                    }
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var mainContentView: some View {
        VStack {
            // Botón de instructivo en la parte superior derecha
            HStack {
                Spacer()
                Button(action: {
                    mostrarInstructivo.toggle()
                }) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                }
            }
            
            Spacer()
            
            // Título
            Text("LogicApp")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 80)
            
            // Cuadros de selección en forma de grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 80) {
                // Lógica de Conjuntos
                NavigationLink(destination: LogicaConjuntosView()) {
                    MenuCard(
                        icon: "square.stack.3d.up.fill",
                        title: "Lógica de Conjuntos",
                        color: .blue
                    )
                }
                
                // Lógica Proposicional
                NavigationLink(destination: LogicaProposicionalView()) {
                    MenuCard(
                        icon: "function",
                        title: "Lógica Proposicional",
                        color: .green
                    )
                }
                
                // Lógica Booleana
                NavigationLink(destination: BooleanLogicView()) {
                    MenuCard(
                        icon: "chart.bar.fill",
                        title: "Lógica Booleana",
                        color: .orange
                    )
                }
                
                // Nuevo botón de Relación
                NavigationLink(destination: DigitalLogicView()) {
                    MenuCard(
                        icon: "arrow.triangle.merge",
                        title: "Relación",
                        color: .red
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Imagen JPG para información
            Button(action: {
                mostrarInformacion.toggle()
            }) {
                Image("tec")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .padding(.bottom, 20)
            }
        }
    }
    
    func setupMovingImages() {
        guard movingImages.isEmpty else { return }

        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        for _ in 0..<8 {
            movingImages.append(MovingImage(
                position: CGPoint(
                    x: CGFloat.random(in: 50...screenWidth-50),
                    y: CGFloat.random(in: 50...screenHeight-50)
                ),
                angle: 0,
                speed: Double.random(in: 0.5...2.0),
                direction: CGPoint(
                    x: CGFloat.random(in: -1...1),
                    y: CGFloat.random(in: -1...1)
                ).normalized()
            ))
        }
    }
    
    func startAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            updateMovingImages()
        }
    }
    
    func updateMovingImages() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        for index in movingImages.indices {
            var newPosition = movingImages[index].position
            newPosition.x += CGFloat(movingImages[index].speed) * movingImages[index].direction.x
            newPosition.y += CGFloat(movingImages[index].speed) * movingImages[index].direction.y
            
            if newPosition.x < 30 || newPosition.x > screenWidth - 30 {
                movingImages[index].direction.x *= -1
            }
            if newPosition.y < 30 || newPosition.y > screenHeight - 30 {
                movingImages[index].direction.y *= -1
            }
            
            var newAngle = movingImages[index].angle + movingImages[index].speed
            if newAngle > 360 { newAngle -= 360 }
            
            movingImages[index].position = newPosition
            movingImages[index].angle = newAngle
        }
    }
}

// MARK: - Extensiones y Vistas Adicionales

// Extensión para detectar el gesto de agitar el dispositivo

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            // Vibración más fuerte - probar diferentes estilos
            let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
            heavyGenerator.prepare()
            heavyGenerator.impactOccurred()
            
            // Opcional: segunda vibración para hacerla más larga
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
                mediumGenerator.impactOccurred()
            }
            
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}


extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

struct ShakeDetector: ViewModifier {
    let onShake: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                onShake()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(ShakeDetector(onShake: action))
    }
}

struct InformacionAlumnoView: View {
    @Binding var mostrarInformacion: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    mostrarInformacion = false
                }
            
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: {
                        mostrarInformacion = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Información del Alumno")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                    
                    HStack {
                        Text("Nombre:")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 120, alignment: .leading)
                        Text("Carlos Angel Selvas Gomez")
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Número de control:")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 120, alignment: .leading)
                        Text("19270181")
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Carrera:")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 120, alignment: .leading)
                        Text("Ingeniería en sistemas computacionales")
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Asesor:")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 120, alignment: .leading)
                        Text("Roberto Cruz Gordillo")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(15)
            }
            .padding(25)
            .frame(width: UIScreen.main.bounds.width * 0.8)
            .background(VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark)))
            .cornerRadius(20)
        }
        .transition(.opacity)
        .zIndex(1)
    }
}

struct InstructivoView: View {
    @Binding var mostrarInstructivo: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    mostrarInstructivo = false
                }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        Button(action: {
                            mostrarInstructivo = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Lógica de Conjuntos").font(.title2).bold().foregroundColor(.white)
                        Text("Cómo usar:").font(.headline).foregroundColor(.white)
                        Text("• Ingresa elementos separados por comas (ej: 1, 2, 3)").foregroundColor(.white)
                        Text("• Selecciona una operación del menú").foregroundColor(.white)
                        Text("• Ejemplos válidos:").font(.headline).foregroundColor(.white)
                        Text("  - Unión: 1, 2, 3 ∪ 2, 3, 4 = {1, 2, 3, 4}").foregroundColor(.white)
                        Text("  - Intersección: 1, 2 ∩ 2, 3 = {2}").foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Lógica Proposicional").font(.title2).bold().foregroundColor(.white)
                        Text("Cómo usar:").font(.headline).foregroundColor(.white)
                        Text("• Usa conectores lógicos: ∧ (y), ∨ (o), → (implica), ¬ (no)").foregroundColor(.white)
                        Text("• Variables proposicionales: P, Q, R, etc.").foregroundColor(.white)
                        Text("• Ejemplos válidos:").font(.headline).foregroundColor(.white)
                        Text("  - P ∧ Q → R").foregroundColor(.white)
                        Text("  - ¬(P ∨ Q) ↔ (¬P ∧ ¬Q)").foregroundColor(.white)
                        Text("  - (P → Q) ∧ (Q → R) → (P → R)").foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Lógica Booleana").font(.title2).bold().foregroundColor(.white)
                        Text("Cómo usar:").font(.headline).foregroundColor(.white)
                        Text("• Usa operadores booleanos: & (AND), | (OR), ^ (XOR), ~ (NOT)").foregroundColor(.white)
                        Text("• Variables booleanas: A, B, C, etc. o 1/0 para verdadero/falso").foregroundColor(.white)
                        Text("• Ejemplos válidos:").font(.headline).foregroundColor(.white)
                        Text("  - A & B | C").foregroundColor(.white)
                        Text("  - ~(A | B) ↔ (~A & ~B) (Ley de De Morgan)").foregroundColor(.white)
                        Text("  - (A & B) ^ (A | C)").foregroundColor(.white)
                        Text("• Las tablas de verdad muestran 1 (verdadero) y 0 (falso)").foregroundColor(.white)
                        Text("• Puedes evaluar propiedades como identidad, dominación, etc.").foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Modo Juego").font(.title2).bold().foregroundColor(.white)
                        Text("Cómo usar:").font(.headline).foregroundColor(.white)
                        Text("• Agita tu dispositivo para activar el modo juego").foregroundColor(.white)
                        Text("• Responde preguntas aleatorias sobre lógica").foregroundColor(.white)
                        Text("• Cada respuesta correcta suma 10 puntos").foregroundColor(.white)
                        Text("• Si respondes mal, se mostrará la respuesta correcta").foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(25)
            }
            .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.7)
            .background(VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark)))
            .cornerRadius(20)
        }
        .transition(.opacity)
        .zIndex(1)
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

extension CGPoint {
    func normalized() -> CGPoint {
        let length = sqrt(x * x + y * y)
        return length > 0 ? CGPoint(x: x / length, y: y / length) : .zero
    }
}

// MARK: - Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
