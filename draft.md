A.2 Report • Design summary (2 pages) – Describe audience and purpose – What aspects of the design you want to get credit for • Pattern or use case summary (2 pages) – Interesting patterns or info that your target audience can discover using your interface – How your tool helped discover these • Sources and references • Group member contribution table

### **Ⅳ. Group Member Contribution Table（组员贡献表）**

| Name  | Contribution to project (≤ 50 words) | Quality of participation (≤ 50 words) | % Contribution |
| ----- | ------------------------------------ | ------------------------------------- | -------------- |
| Bichaun Liu | 负责 R Shiny 主界面与子页面和tableau的集成         | 积极参与每周会议，按时提交                         | 25%            |
| Boyan Liu   | 实现 Tableau 可视化         | 沟通良好，解决技术问题                           | 25%            |
| Xiaolin Liu | 负责transit 和 dining子页面开发         | 主动协调数据任务                              | 25%            |
| Anran Zhang | 负责map页面开发                       | 协作高效、注重细节                             | 25%            |
|       |                                      |                                       |                |

我现在要给我这个项目写报告，以上是要求，以下是我已经有了的部分
请你结合这两部分和我的代码，帮我写一个完整的报告

Design SummaryThe "Journey Planner" is an interactive map module for Melbourne's CBD designed to provide a single, optimal route recommendation. It simplifies navigation by automatically computing the shortest total journey distance across three modes (walking-only, walk-plus-bus, walk-plus-tram) and presenting only that one clear, actionable route.The interface works via "Direct Manipulation": users set their origin by clicking anywhere on the map and their destination by clicking a landmark icon. This interaction is reinforced by persistent textual feedback in a status panel, a principle from Don Norman that builds user trust.When "Calculate" is clicked, the backend finds the nearest stops (via distHaversine) and then calculates the full street-network distance for all three journey types using osrmRoute, crucially including the walking legs to and from the stops.The module's primary design feature is its "Single Recommendation" approach. This decision is justified by Hick's Law: by reducing the choice from three complex routes to one simple answer, it dramatically lowers the user's cognitive load. Overview first, filter, then details-on-demand), where the final route is the requested "detail."This clarity is supported by preattentive attributes (distinct colors for bus, tram, and walk routes). Finally, with leafletProxy for seamless dynamic updates, the map can be modified without re-loading, leaving the user directed. This makes it a powerful, intuitive, and lightweight tool to replace raw data with meaningful answers.Pattern and Use Case SummaryThe "Journey Planner" interface is designed to move beyond simple data exploration and provide actionable, data-driven recommendations. It targets both tourists (unfamiliar with the city's transit network) and locals (who seek to optimise short-distance travel). The design enables the discovery of non-obvious travel patterns by comparing total journey distance across multiple modes.A tourist at a hotel on Collins Street and needs to go to the State Library of Victoria. It's about 700 to 800 meters. A tram line runs directly between the two points. The user's question is: "Is it faster to walk, or should get on the tram?"The user sets their origin and destination and clicks "Calculate Route." The interface displays a black dashed line—the "Walking Only" route.The user discovers that for this distance, the "tipping point" has been crossed: 
walking directly is a shorter total journey than the perceived convenience of the tram. The tool's calculation correctly models that the total distance of the tram journey (walking to the stop, riding, then walking from the stop to the final destination) is greater than the direct walk.The tool’s route model is holistic. It correctly models and sums the entire journey. It is this precise door-to-door modelling that makes it possible to expose this unapparent pattern, and to avoid making a less effective choice on the basis of the simple and misleading fact that a tramway "runs right there."The interface calculates the minimum and shows only one, it leverages Hick's Law: reducing the number of choices (from 3 to 1) dramatically speeds up the user's decision-making process.

## **Design Summary**

This interface is an interactive data visualization system developed with **R Shiny**, designed to present insights about Melbourne’s central business district (CBD), focusing on **public transport accessibility** and **restaurant distribution** around major landmarks. The system consists of two dedicated subpages within a unified navigation layout, enabling users to switch seamlessly between different analytical perspectives:

- **Table A – Landmark Public Transport Accessibility**
- **Chart B – Nearby Restaurants and Seating Capacity**

### (1) Core Functions and Working Mechanism

**Table A** displays each landmark’s distance to its nearest **bus** and **tram** stops. Users can filter landmarks by *Theme* and *Sub-Theme*, or apply an optional *maximum distance filter* to focus on certain areas. The system calculates all pairwise **Haversine distances** between landmarks and transport stops, identifies the nearest ones, and visualizes results using a sortable, colored horizontal bar chart—blue for “bus closer,” orange for “tram closer.”
 Below the chart, an interactive table (with CSV/Excel export options) provides full data access, ensuring both **explorability and traceability** of results.

**Chart B** shifts focus to restaurants surrounding a selected landmark. Users can select a landmark, set a search *radius (100–1000 m)*, adjust *Top N results*, and choose sorting by either **distance** or **total seating capacity**. The visualization uses a **dual-axis horizontal bar chart**:

- Blue bars (left axis) represent distance;
- Orange bars (right axis) represent total seating capacity.
   This side-by-side layout allows direct comparison between proximity and available capacity within a single cohesive view.

### (2) Design Highlights and Rationale

**1. Modular and Navigable Structure**
 The use of `navbarPage()` separates two major analytical tasks—transport and restaurant analysis—following **Information Hierarchy** principles. This modularity reduces cognitive overload and aligns with multi-perspective exploratory workflows.

**2. Dual-Axis Comparative Visualization**
 The dual-axis bar chart in Chart B is a key innovation. By overlaying two numerical dimensions (distance and seating capacity), it supports relational insight discovery that single-axis plots cannot provide. This design is grounded in **Cognitive Fit Theory**, ensuring that the visualization form aligns with users’ analytical goals.

**3. Semantic Color Encoding**
 Color design follows a meaningful scheme: blue represents bus (stability and coverage), orange represents tram (vibrancy and centrality). This contrast is both **semantically intuitive** and **perceptually efficient**, aligning with the **Gestalt Contrast Principle** and **Pre-attentive Feature Theory**, allowing users to instantly differentiate transport modes.

**4. Responsive Data and Robustness**
 Reactive data handling ensures instant updates when users change inputs (filters, radius, sorting). Edge cases (e.g., missing data) are gracefully handled through empty chart placeholders, ensuring stability and a smooth user experience—key aspects of **usability and system robustness**.

**5. Minimalist Design and Cognitive Efficiency**
 The visualization focuses on data clarity: only short labels and numerical values are shown directly, while full details are accessible via hover tooltips. This approach reduces unnecessary ink and adheres to **Tufte’s Data-Ink Ratio** and **Cognitive Load Reduction** principles, maximizing information density without overwhelming the viewer.

Overall, the interface exemplifies a balance between **analytical precision and visual simplicity**, allowing both professionals and general users to explore complex urban data through clear, responsive, and aesthetically coherent design.

------

## **Pattern / Use Case Summary**

### (1) Target Users and Purpose

The system is intended for a diverse audience, including:

1. **Urban planners and transport authorities** – to assess landmark accessibility, identify coverage gaps, and support network optimization;
2. **Commercial analysts and business investors** – to evaluate restaurant density and seating capacity around major attractions for location planning;
3. **Tourists and city explorers** – to plan efficient travel routes and find areas with convenient transport and abundant dining options.

By combining spatial, functional, and service-level information, the interface enables users to uncover actionable patterns: where access is easiest, where services cluster, and how infrastructure and amenities interact spatially.

### (2) Insights and Patterns Revealed by the System

**① Landmark Transport Coverage and Accessibility Hierarchies**
 In **Table A**, Haversine distance calculations reveal hierarchical patterns of accessibility across different landmark types.

- **Ranking Insight:** Sorting landmarks by ascending minimum distance brings the most accessible sites to the top. For instance, when filtering “Cultural Facilities,” museums and theaters appear among the most accessible, reflecting their strategic positioning within the tram loop.
- **Color Pattern Insight:** The mix of blue (bus closer) and orange (tram closer) bars visualizes transport network distribution—bus routes serve dispersed outer areas, while trams concentrate within the city core.
- **Spatial Correlation:** Users can easily observe functional dependencies, e.g., educational institutions tend to rely on buses, whereas arts and heritage sites align with tram accessibility.
   This transformation from spatial data to a **visual hierarchy** simplifies urban network analysis, turning geographic complexity into an intuitive 1D ranking model.

**② Restaurant Spatial-Capacity Gradient and Accessibility Trade-offs**
 In **Chart B**, the dual-axis design reveals a **negative spatial-capacity gradient** between restaurant proximity and size.

- **Gradient Observation:** Restaurants closer to landmarks are numerous but typically smaller in seating capacity, while those further away are fewer but larger. This pattern reflects the typical **“high-density, low-space”** structure of Melbourne’s CBD.
- **Dynamic Sorting Insight:**
  - Sorting by *Distance (asc)* exposes the “convenience layer,” highlighting the densest clusters of nearby dining options.
  - Sorting by *Capacity (desc)* shifts focus to “resource strength,” helping users locate large venues suitable for groups or events.
- **Decision Implications:**
  - For planners, this highlights potential “overloaded zones” with high demand but limited capacity, or “underutilized peripheries” with available space.
  - For tourists, it suggests whether to dine close to a landmark for convenience or walk slightly further for more spacious options.

The hover-enabled details (“distance,” “total seats,” “name”) support **information drill-down**, allowing users to shift fluidly from macro patterns to micro-level insights. This directly reflects **Shneiderman’s Visual Information-Seeking Mantra**—*Overview → Zoom → Filter → Details-on-Demand*—enabling deep yet effortless exploration.

**③ Exploration-Driven Discovery Process**
 Both subpages adopt a reactive model where user input immediately triggers recalculation and re-rendering. This interaction loop fosters a **hypothesis–test–discover** workflow: users can first identify transport-accessible landmarks in Table A, then analyze their surrounding amenities in Chart B.
 The design thus transforms data analysis into an **analytical narrative**, guiding users naturally across layers of spatial reasoning—from accessibility to service distribution—supporting pattern recognition and decision-making across domains.

Design SummaryThe Melbourne Visitor Readiness Dashboard facilitates prompt and persuasive assessments of landmark accessibility by combining rankings, spatial context, and mechanism-level interpretations onto a single page. To facilitate comparison, We created a thorough Visitor Readiness Index to make comparisons easier. It converts data elements of different kinds, scales, and units (such as the number of cafes, the number of seats in restaurants, and the walking distance to the closest public transportation) onto a single, monotonic comparative scale. Service coverage is parameterized by p.Radius (m), centered at each landmark. Distances between landmarks and sites/venues are calculated as great-circle distances. Restaurant service records are first consolidated at the property level and then aggregated within the service coverage to avoid double counting. All landmark-level measurements are calculated using a fixed level of detail, meaning they are aggregated at a fixed granularity for the landmark. This ensures that statistics for each landmark are calculated on the same basis when filtering and sorting, ensuring numerical stability and traceability.In visual terms, the dashboard comprises three complementary views comprises three complementary views. Top Landmarks by Visit Readiness orders sites by VRI to produce an interpretable shortlist; colour encodes the Limiting Factor, while labels/tooltips report nearest-stop distance, cafes in the catchment, and total seats for clarity. The Landmarks Map situates the same sites in their urban context, indicating where high- or low-ranking landmarks are located, whether they sit along transit corridors, and whether nearby dining clusters exist. Marker size conveys capacity differences, and tooltips provide the nearest mode of transportation, station name, and walking distance to verify accessibility assumptions. The Access vs Dining Capacity explains the structural trade-off. The horizontal axis represents nearest public-transport distance, the vertical axis represents seats within the catchment, and point size reflects cafe count. Two median reference lines partition the plane into “near/far” and “low/high” regimes, enabling quick identification of candidates with low friction and high throughput (top left) and scenarios with low throughput in both dimensions (bottom right).Pattern / Use Case SummaryThe user first sets p.Radius (m) to reflect a realistic walk. The user then consults Top Landmarks by Visit Readiness to form a shortlist. The bar colour (Transit, Cafes, or Seats) indicates the main constraint for each site, so the user obtains not only an ordering but also an explanation. Then, check the Landmarks Map to verify spatial context. Finally, use Access vs Dining Capacity to interpret the trade-off: points toward the left and higher on the plot indicate near-transit locations with more seats in the catchment, which are suitable for low-effort visits; points toward the right and lower are weak on both access 
and capacity and may require mitigation such as clearer wayfinding, first/last-mile support, or temporary food provision during events.Across the three views, the user can observe several simple patterns. The distance from a landmark to the nearest stop often drives the access cost; once this distance is large enough, walking straight to the destination can be more practical than “walk–ride–walk.” Inner-city landmarks usually have shorter nearest-stop distances but vary in nearby seating capacity. The colour-coded Limiting Factor points to a single main constraint for each site—Transit, Cafes, or Seats—so the response is straightforward， such as improving access for transit-limited sites; adding temporary seating or vendors where capacity is the issue. This version focuses on two ingredients only: access and nearby dining capacity. It does not model opening hours, cuisine mix, or real-time crowding.