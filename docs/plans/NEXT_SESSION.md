# Execution Plan: Session 02 - "Hardening & Hollywood"

**Goal:** Transform the functional prototype into a production-ready demo for the Hackathon submission video.

## 1. Hard Tech Integration (Noir & Identity)
- [ ] **Generate Artifacts:** Run `nargo prove` on `circuits/agent_badge` to get a real proof string.
- [ ] **SDK Wiring:** Update `sdk/src/agent.ts` to load this proof into the `AgentContext`.
- [ ] **UI Consistency:** Ensure the Hub displays the actual proof hash in the Identity Badge tooltip.

## 2. The Hollywood Script (Storytelling)
- [ ] **Create `docs/DEMO_SCRIPT.md`:** A second-by-second screenplay for the video recording.
    - **Scene 1:** The Problem (Unbanked Agents).
    - **Scene 2:** Privacy in Action (Starpay -> Light).
    - **Scene 3:** The Guardrails (Range Protocol Block).
    - **Scene 4:** The Unicorn Feature (Shadow Governance & Approval).
    - **Scene 5:** The Receipts (Hybrid Invoice Protocol).

## 3. The "Golden Path" Verification (QA)
- [ ] **End-to-End Run:** Execute the full flow without refreshing the page.
- [ ] **Visual Polish:** Ensure animations (Goverance Lock, Invoice Modal) are smooth.
- [ ] **Reset Mechanism:** Create a simple script/button to clear the DB state for effortless retakes of the video.

## 4. Documentation for VCs
- [ ] **Update Root README:** Make it "Investor Ready" (Screenshots, Vision, Architecture).
- [ ] **Clean Codebase:** Remove obvious "TODOs" or commented-out code in critical paths.
