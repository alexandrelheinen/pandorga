#!/usr/bin/env node
/**
 * parseContentWorkflowFromConfig — reads pandorga.content.workflow from _config.yml.
 */
import assert from "node:assert/strict";
import { parseContentWorkflowFromConfig } from "../../functions/api/studio/_lib/github.js";

const sample = `# site
title: Example

pandorga:
  # comment above content
  content:
    backend: r2
    base_url: https://example.invalid
    # Actions workflow Studio watches after Save
    workflow: content-pipeline.yml
    workflow_ref: main
  identity:
    name: Example
`;

const parsed = parseContentWorkflowFromConfig(sample);
assert.equal(parsed.workflow, "content-pipeline.yml");
assert.equal(parsed.workflowRef, "main");

const missing = parseContentWorkflowFromConfig("pandorga:\n  identity:\n    name: x\n");
assert.equal(missing.workflow, null);

const quoted = parseContentWorkflowFromConfig(
  "pandorga:\n  content:\n    workflow: \"my-workflow.yml\"\n"
);
assert.equal(quoted.workflow, "my-workflow.yml");

console.log("All Studio pipeline config parse checks passed.");
