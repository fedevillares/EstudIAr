class PromptSanitizer {
  static String sanitize(String prompt) {
    // Remove any potentially harmful content
    return prompt
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll('\'', '&apos;')
        .replaceAll('&', '&amp;');
  }
}