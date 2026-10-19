# ML Kit Text Recognition ships the non-Latin script recognizers as
# `compileOnly` artifacts. The app only creates
# `TextRecognizer(script: TextRecognitionScript.latin)`, so those classes are
# never resolved at runtime and R8 must not fail on them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
