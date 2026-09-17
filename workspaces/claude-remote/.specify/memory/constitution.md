<!--
Sync Impact Report:
Version change: Template → 1.0.0
Modified principles: All principles defined from template
Added sections: Quality Standards, Development Workflow  
Removed sections: None
Templates requiring updates: ✅ All templates reviewed and consistent
Follow-up TODOs: None
-->

# Claude Remote Constitution

## Core Principles

### I. Specification-First
Every feature begins with a complete specification before any implementation work. Specifications must be written in natural language for business stakeholders, avoiding technical implementation details. All requirements must be testable and unambiguous with clear acceptance criteria.

### II. Template-Driven Development  
All artifacts follow standardized templates to ensure consistency and completeness. Templates provide structure for specifications, plans, tasks, and documentation. Deviations from templates must be explicitly justified and documented.

### III. Test-First (NON-NEGOTIABLE)
TDD is mandatory: Tests are written first, must fail, then implementation makes them pass. Contract tests verify API specifications, integration tests validate user scenarios, and unit tests ensure component reliability. No implementation without failing tests.

### IV. Phased Development Process
Development follows a strict phase sequence: Specification → Planning → Task Generation → Implementation → Validation. Each phase must complete successfully before proceeding to the next. Gates ensure quality and completeness at each transition.

### V. Documentation-Driven Quality
Clear documentation is required at every development phase. Research findings, design decisions, and implementation approaches must be documented with rationale. Agent-specific context files maintain consistency across development sessions.

## Quality Standards

All code must pass linting and type checking before commit. Performance requirements must be explicitly defined and validated. Security considerations must be documented and implemented. Error handling and logging are mandatory for all components.

## Development Workflow

Constitution compliance is verified at each development phase. All pull requests must demonstrate adherence to constitutional principles. Complexity that violates principles must be explicitly justified with simpler alternatives considered and rejected with documented rationale.

## Governance

This constitution supersedes all other development practices and guidelines. Amendments require documentation of the change rationale, impact assessment, and migration plan for existing work. All development artifacts must demonstrate compliance with constitutional principles through explicit verification steps.

**Version**: 1.0.0 | **Ratified**: 2025-09-23 | **Last Amended**: 2025-09-23