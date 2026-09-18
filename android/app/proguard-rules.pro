# ONNX Runtime (flutter_onnxruntime) goi nguoc vao cac class Java duoi day
# tu native code qua JNI (GetMethodID/FindClass bang ten chuoi, khong phai
# tham chieu Java thong thuong) — R8 khong lan ra duoc nen tuong nham la
# khong dung toi va xoa/doi ten mat trong ban release, gay crash "JNI
# DETECTED ERROR IN APPLICATION: java_class == null" (ClassNotFoundException
# ai.onnxruntime.TensorInfo) chi khi build --release, khong xay ra ở debug.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
