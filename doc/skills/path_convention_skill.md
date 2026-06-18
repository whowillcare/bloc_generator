# Markdown Path Convention Skill

Use this skill to ensure all documentation, walkthroughs, plans, task lists, and other Markdown files follow the correct path formatting convention.

## Rule

When creating or modifying any Markdown (`.md`) files in this repository (e.g., in `doc/` or `manager/doc/`):
* **Do NOT use absolute paths** (e.g., `file:///home/sam/Projects/robot_arm/...` or `/home/sam/Projects/robot_arm/...`).
* **Use relative paths** relative to the project root directory instead (e.g., `lib/bloc/cron_bloc.yaml`, `manager/lib/main.dart`).

## Examples

* **Incorrect**:
  `Modify the [cron_bloc.yaml](file:///home/sam/Projects/robot_arm/flutter/arm-recipes/lib/bloc/cron_bloc.yaml) file...`

* **Correct**:
  `Modify the [cron_bloc.yaml](lib/bloc/cron_bloc.yaml) file...`
