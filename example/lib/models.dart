class DictWord {
  final String word;
  const DictWord({required this.word});

  factory DictWord.fromJson(Map<String, dynamic> json) => DictWord(
        word: json['word'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'word': word,
      };
}

enum DictStatus {
  init;

  factory DictStatus.fromJson(String json) => DictStatus.init;
  String toJson() => 'init';
}

enum DictAction {
  someAction;

  factory DictAction.fromJson(String json) => DictAction.someAction;
  String toJson() => 'someAction';
}

class DictError {
  DictError();
  factory DictError.fromJson(Map<String, dynamic> json) => DictError();
  Map<String, dynamic> toJson() => {};
}
