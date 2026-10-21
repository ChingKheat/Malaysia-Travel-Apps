# Chapter 3: Methodology and Requirements Analysis

## 3.2 Software Development Methodology

In software engineering, selecting an appropriate software development life cycle (SDLC) methodology is critical to project success. The chosen methodology dictates how requirements are analyzed, how code is structured and updated, how testing is integrated, and how risks are managed. For the *Smart Travel Planning Mobile Application*, several software development methodologies are potentially suitable, each presenting unique advantages and constraints. 

Below is a detailed review and evaluation of four key methodologies considered for this project: the Waterfall Model, the Prototyping Model, the Spiral Model, and the Agile Methodology.

---

### 3.2.1 Review of Potential Software Development Methodologies

#### 1. Waterfall Methodology
The Waterfall model is a traditional, linear, and sequential software development life cycle. It is divided into distinct, non-overlapping phases: Requirements Gathering, System Design, Implementation, Integration and Testing, Deployment, and Maintenance. Progress flows steadily downwards, like a waterfall, where each phase must be fully completed and documented before the next phase begins.

* **Strengths**: 
  * Easy to manage due to its rigid structure: each phase has specific deliverables and a review process.
  * Clear documentation is produced at every step, which is beneficial for tracking requirements and architectural design.
  * Well-suited for projects with stable, well-understood requirements that are highly unlikely to change during development.
* **Weaknesses**:
  * Highly inflexible; it is extremely difficult and costly to go back to a previous phase to make changes once implementation has begun.
  * Working software is only produced late in the development cycle, which increases risk.
  * Poorly suited for modern mobile applications that integrate third-party APIs, as API behaviors, responses, and rate limits cannot be fully understood until active implementation begins.

#### 2. Prototyping Model
The Prototyping methodology focuses on building an early, simplified version of the software application—known as a prototype—to demonstrate basic functionalities to stakeholders. The development process is cyclic: requirements are gathered, a quick prototype is built, the user evaluates it, and requirements are refined based on feedback. This cycle continues until the design is approved, after which the actual system is built.

* **Strengths**:
  * Improves requirement accuracy because users can interact with a visual prototype and provide feedback on the user interface (UI) and user experience (UX).
  * Reduces risk of project failure by identifying design flaws and usability issues early in the design stage.
  * Promotes active stakeholder engagement.
* **Weaknesses**:
  * Can lead to "scope creep" as constant feedback can result in endless requests for new features.
  * Quick prototypes are often built using temporary code and poor design patterns, which developers may be tempted to reuse in the final production app, resulting in a suboptimal architecture.
  * Does not provide a structured framework for managing actual coding sprints, testing schedules, or deployment.

#### 3. Spiral Model
The Spiral model is a evolutionary, risk-driven SDLC model that combines the iterative nature of prototyping with the controlled, systematic aspects of the Waterfall model. The development process is represented as a spiral, where the project passes through four quadrants repeatedly: Objectives Determination, Risk Analysis and Evaluation, Engineering/Development, and Next Phase Planning.

* **Strengths**:
  * Excellent risk management: every iteration begins with a thorough identification and resolution of potential risks (e.g., API failures, budget overruns).
  * Good for large, complex, and high-risk systems.
  * Accommodates changes during development through repeated planning cycles.
* **Weaknesses**:
  * Highly complex and requires specialized expertise in risk assessment.
  * Significant administrative overhead and documentation requirements, making it time-consuming.
  * Unsuitable for small-scale or individual academic projects where developer resources are limited.

#### 4. Agile Methodology (Recommended)
Agile is an iterative and incremental development methodology that prioritizes flexibility, collaboration, and rapid delivery of working software. The project is broken down into small, manageable increments called Sprints (typically 1 to 2 weeks long). During each Sprint, a cross-functional cycle of requirement analysis, design, development, and testing is performed, leading to a functional software release at the end of the sprint.

* **Strengths**:
  * Extremely flexible: requirements can adapt based on technical discoveries (e.g., API response changes) and changing user needs.
  * Encourages early integration and continuous testing: working features are deployed and validated in every iteration.
  * Reduces development risk: issues are identified in small increments rather than at the end of the project.
* **Weaknesses**:
  * Demands continuous effort and engagement from developers and supervisors.
  * The lack of rigid structure can sometimes lead to project timeline slippages if the scope is not strictly managed.
  * Relies less on exhaustive upfront documentation, which requires discipline to maintain up-to-date documentation.

---

### 3.2.2 Comparison of Software Development Methodologies

To evaluate the feasibility of these methodologies for the *Smart Travel Planning Mobile Application*, Table 3.1 compares them across parameters relevant to this project (API integration complexity, UI flexibility, and academic project suitability).

#### Table 3.1: Comparison of SDLC Methodologies for the Smart Travel Planner Project

| Evaluation Parameter | Waterfall Model | Prototyping Model | Spiral Model | Agile Methodology |
| :--- | :--- | :--- | :--- | :--- |
| **Flexibility to Changes** | Low (Very rigid) | High | High | **Very High** |
| **Risk Management** | Low (Discovered late) | Medium | **High (Risk-driven)** | High (Iterative testing) |
| **API Integration Fit** | Poor (Requires stable specs) | Medium | Good | **Excellent (Continuous testing)** |
| **Working Software Delivery**| Only at the end | Early prototype only | Incremental versions | **Continuous working increments** |
| **Complexity & Overhead** | Low overhead | Low to Medium | High (Heavy overhead) | **Low to Medium** |
| **Suitability for FYP Project**| Low | Medium | Low | **High** |

---

### 3.2.3 Justification for Selecting the Agile Methodology

For the development of the *Smart Travel Planning Mobile Application*, the **Agile Software Development Methodology** is selected as the most suitable approach. The justification is based on several factors specific to the technical and logistical scope of this project:

1. **Complex Third-Party API Integrations**: 
   The core functionality of the application depends on integrating multiple external REST APIs: **OpenTripMap API** (attraction retrieval), **OpenRouteService API** (driving routes and travel time calculation), and **OpenWeatherMap API** (dynamic weather forecast constraint checking). In a Waterfall approach, any unexpected API outage, changes in API data structures, or strict rate-limiting policies discovered late in development would require a costly rewrite of the system design. Agile allows the developer to build, test, and refine API service classes (e.g., `itinerary_service.dart`, `openroute_service.dart`) incrementally, discovering rate limit challenges early in the process.
   
2. **Iterative Algorithm Refinement**: 
   The dynamic itinerary generator uses a greedy nearest-neighbor heuristic that must evaluate travel time, visit duration, and user budgets. Finding the optimal values (e.g., setting travel speed to an average of 28 km/h or setting default visit durations to 45 minutes) requires running empirical tests and adjusting coefficients. Agile supports iterative refinement where the developer can write a basic algorithm in Sprint 1, test it, and then implement advanced constraints (like weather integration) in subsequent sprints.
   
3. **Continuous UI/UX Feedback**: 
   Since this is a mobile application built using Flutter, the design of the interactive maps (`flutter_map`), markers, routes, and budget inputs requires constant visual alignment and testing. The incremental nature of Agile ensures that the UI can be continuously tweaked and tested on physical Android devices to ensure optimal layout, alignment, and responsiveness.
   
4. **Time-Boxed Delivery for FYP Constraints**: 
   As an academic project, the development timeline is strictly time-boxed. Agile enables the developer to prioritize core functionalities (the "Minimum Viable Product" or MVP) first—such as loading the map and routing two coordinates—before proceeding to secondary modules like multi-language localization or weather updates. This guarantees that a working prototype is always available for presentation, minimizing the risk of project incompletion.
