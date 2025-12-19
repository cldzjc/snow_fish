pluginManagement {
  repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
  }
  
  resolutionStrategy {
    eachPlugin {
      if (requested.id.id == "dev.flutter.flutter-gradle-plugin") {
        useModule("dev.flutter:flutter-gradle-plugin:${requested.version}")
      }
    }
  }
}

include(":app")
