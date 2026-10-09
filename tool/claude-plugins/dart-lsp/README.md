# dart-lsp (Claude Code plugin)

Gives Claude Code Dart/Flutter code intelligence (diagnostics, go-to-definition, references) through the Dart SDK's own language server, `dart language-server`. The server definition lives inline in `/.claude-plugin/marketplace.json`.

Requirement: `dart` must be on `PATH` **as an executable**. On Windows that means adding `<flutter>\bin\cache\dart-sdk\bin` (which contains `dart.exe`) to PATH, because Flutter's `bin\dart.bat` cannot be launched without a shell.

The project enables it in `.claude/settings.json` (`dart-lsp@footnoted-tools`). The marketplace is this repository (`JohnnnyTang/footnoted`).

Install manually (the project settings normally prompt for it):

    /plugin install dart-lsp --marketplace JohnnnyTang/footnoted
