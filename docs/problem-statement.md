# Problem Statement

## Challenge

Supply chain data is fragmented across ERP, supplier, logistics, inventory, and operational
systems. Teams often define the same business concepts differently, producing conflicting
answers to basic operational questions.

Planning, procurement, and logistics may therefore calculate metrics such as On-Time Delivery
or Fill Rate differently even when they are discussing the same supply chain.

## Ontara

Ontara is a governed supply chain intelligence layer built on Snowflake.

It provides:

- a shared supply chain ontology,
- canonical business metrics,
- governed semantic views,
- natural-language analytics,
- explainable metric resolution,
- operational blast-radius analysis,
- human-approved supply actions,
- an auditable exception workflow.

## Core Relationship

Supplier -> Part -> Plant -> Shipment -> Order -> Customer

## Primary Acceptance Condition

Equivalent business questions asked by Planning, Procurement, and Logistics must resolve to
the same canonical metric definition and produce the same result for the same scope.

## Product Principle

One supply chain. Shared definitions. Trusted answers.
