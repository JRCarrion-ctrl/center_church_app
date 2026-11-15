# Gemini Repository Instructions & Workspace Guidelines

## Overview
This repository contains a Flutter application (`ccf_app`) for community management and church services. When generating code, debugging, refactoring, or assisting with tasks, you must adhere strictly to the project architecture, null-safety rules, and domain-specific workflows.

## Imported Skills & Rule Directory
All agent skills, architectural patterns, and workflow guidelines are located in the `.agents/skills/` directory. 
- **Rule Lookup:** Whenever a user request corresponds to a Dart or Flutter task (e.g., UI layout, routing, HTTP networking, state management, testing), consult the relevant skill instructions inside `.agents/skills/` before generating code.
- **Idiomatic Code:** Follow modern Flutter best practices, Riverpod state management patterns, and robust error handling.

## Code Standards
1. **Static Analysis:** Ensure all generated code passes strict Dart analyzer checks (`dart analyze`).
2. **Null Safety:** Strictly adhere to Dart sound null safety principles.
3. **Responsive UI:** Build layouts supporting multi-screen adaptation following the project's design guidelines.