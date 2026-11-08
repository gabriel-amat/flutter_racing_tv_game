class ControlInput {
  final double steering; // -1.0 (esquerda total) a +1.0 (direita total)
  final bool throttle;   // acelerando
  final bool brake;      // freando / ré
  final bool nitro;      // turbo ativado
  final int timestamp;   // para cálculo de ping

  const ControlInput({
    this.steering = 0.0,
    this.throttle = false,
    this.brake = false,
    this.nitro = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': 'input',
    's': double.parse(steering.toStringAsFixed(3)),
    't': throttle,
    'b': brake,
    'n': nitro,
    'ts': timestamp,
  };

  factory ControlInput.fromJson(Map<String, dynamic> json) {
    return ControlInput(
      steering: (json['s'] as num?)?.toDouble() ?? 0.0,
      throttle: json['t'] as bool? ?? false,
      brake: json['b'] as bool? ?? false,
      nitro: json['n'] as bool? ?? false,
      timestamp: json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
