def multiplicador_secuencial_4bits(A: int, B: int) -> int:
    """
    Simula exactamente el diagrama de bloques del multiplicador de 4 bits:
    - A: Multiplicando (4 bits: 0 a 15)
    - B: Multiplicador (4 bits: 0 a 15)
    - Q: Registro síncrono de 8 bits (Q7..Q4 | Q3..Q0)
    """
    A &= 0xF
    B &= 0xF

    # 1. LOAD = 1: Carga 0000 en la parte alta y B3..B0 en la parte baja
    Q = B  # Equivale a (0b0000 << 4) | B

    # 2. 4 pulsos de reloj (desplazamiento y suma)
    for ciclo in range(4):
        q0 = Q & 1                        # Bit menos significativo (Q0)
        pp = A if q0 == 1 else 0          # Productos parciales: PPi = Ai * Q0
        q_alto = (Q >> 4) & 0xF           # Parte alta actual: Q7..Q4
        q_bajo_desplazado = (Q & 0xF) >> 1  # Q3..Q1

        # Sumador de 4 bits: (Q7..Q4) + PP -> genera {Cout, S3..S0} (5 bits)
        suma_5bits = q_alto + pp

        # Nuevo registro Q: {Cout, S3..S0, Q3, Q2, Q1}
        Q = (suma_5bits << 3) | q_bajo_desplazado

    return Q


# --- Pruebas de verificación ---
if __name__ == "__main__":
    # Probar casos específicos
    for a, b in [(3, 5), (10, 12), (15, 15), (0, 9)]:
        res = multiplicador_secuencial_4bits(a, b)
        print(f"{a:2d} x {b:2d} = {res:3d} (binario: {res:08b})")

    # Barrido completo de las 256 combinaciones (0..15 x 0..15)
    for a in range(16):
        for b in range(16):
            assert multiplicador_secuencial_4bits(a, b) == a * b, f"Error en {a} * {b}"

    print("Todas las 256 combinaciones pasaron correctamente.")
