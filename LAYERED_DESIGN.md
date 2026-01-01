# Layered Design Structure

## Visual Hierarchy

The app now uses a sophisticated layered design with different background tints for each section, creating depth and visual separation.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         App Window                                   │
├──────────┬──────────────────────┬───────────────────────────────────┤
│          │                      │                                    │
│ Sidebar  │  Notification List   │     Detail View                   │
│          │                      │                                    │
│ Layer 1  │     Layer 2          │        Layer 3                    │
│ Blue +   │   Cyan + Blue        │  Base + Blue/Purple/Pink          │
│ Purple   │   Gradient           │  Gradient                         │
│ 0.05     │   0.04               │  0.04                             │
│          │                      │                                    │
│          │                      │  ┌─────────────────────────┐     │
│          │                      │  │ Title & Body Card       │     │
│          │                      │  │                         │     │
│          │                      │  │ • Blue tint header     │     │
│          │                      │  │ • White body section   │     │
│          │                      │  │                         │     │
│          │                      │  └─────────────────────────┘     │
│          │                      │                                    │
│          │                      │  ┌─────────────────────────┐     │
│          │                      │  │ Comments Card           │     │
│          │                      │  │                         │     │
│          │                      │  │ • Purple tint header   │     │
│          │                      │  │ • Comment items        │     │
│          │                      │  │   └─ Nested cards      │     │
│          │                      │  │                         │     │
│          │                      │  └─────────────────────────┘     │
│          │                      │                                    │
└──────────┴──────────────────────┴───────────────────────────────────┘
```

## Layer Breakdown

### Layer 1: Sidebar (Left Column)
**Background:**
- Base: `windowBackgroundColor` at 30% opacity
- Gradient: Blue (0.05) → Purple (0.05)
- Direction: Top to Bottom

**Purpose:** Most prominent blue tint to establish the left navigation area

### Layer 2: Notification List (Middle Column)
**Background:**
- Base: `windowBackgroundColor` at 40% opacity
- Gradient: Cyan (0.04) → Blue (0.04)
- Direction: Top to Bottom

**Purpose:** Slightly different tint (cyan-blue) to distinguish from sidebar

### Layer 3: Detail View (Right Column)
**Background:**
- Base: `windowBackgroundColor` at 50% opacity
- Gradient: White (0.03) → Grey (0.02)
- Direction: Top to Bottom

**Purpose:** Clean, neutral background for content readability

## Card Structure

### Title & Body Card (Unified)
```
┌────────────────────────────────────┐
│ Header Section                     │
│ • Repository name                  │
│ • Title                            │
│ • State badge                      │
│ Background: Blue 0.02              │
├────────────────────────────────────┤
│ Body Section                       │
│ • Author info                      │
│ • Description                      │
│ • View on GitHub button            │
│ Background: Transparent            │
└────────────────────────────────────┘
   ↑ All wrapped in glass effect
```

### Comments Card (Unified)
```
┌────────────────────────────────────┐
│ Header Section                     │
│ • Comments title                   │
│ • Count badge                      │
│ Background: Purple 0.02            │
├────────────────────────────────────┤
│ Comments List                      │
│ ┌──────────────────────────────┐  │
│ │ Comment 1                    │  │
│ │ • White 0.03 background      │  │
│ │ • Subtle border              │  │
│ └──────────────────────────────┘  │
│ ┌──────────────────────────────┐  │
│ │ Comment 2                    │  │
│ └──────────────────────────────┘  │
│ Background: Transparent            │
└────────────────────────────────────┘
   ↑ All wrapped in glass effect
```

## Color Coding

### Section Headers (Tinted Backgrounds)
- **Title Header**: Blue 0.02 - Links to notification subject
- **Comments Header**: Purple 0.02 - Distinct section indicator

### Individual Comments
- **Background**: White 0.03 - Subtle elevation
- **Border**: White 0.08 - Defined edges
- **No glass effect**: Nested inside parent glass container

## Opacity Scale

The opacity values are carefully chosen for optimal contrast:

1. **Sidebar**: 0.05 opacity (most visible gradient)
2. **List**: 0.04 opacity (medium visibility)
3. **Detail background**: 0.04 opacity (balanced)
4. **Card headers**: 0.02 opacity (subtle tint)
5. **Comment items**: 0.03 opacity (nested elements)

## Visual Flow

1. **Left to Right**: Gradual color transition from blue → cyan → neutral grey
2. **Top to Bottom**: Within cards, headers are tinted, bodies are neutral
3. **Depth**: Glass effects on cards create elevation above backgrounds

## Benefits

✅ **Clear Separation**: Each column has distinct visual identity  
✅ **Logical Grouping**: Related content grouped in single cards  
✅ **Visual Hierarchy**: Headers tinted, content neutral  
✅ **Depth Perception**: Multiple layers create 3D effect  
✅ **Readability**: Subtle tints don't interfere with text  
✅ **Cohesive Design**: All elements follow same design system  

## Technical Implementation

### Background Pattern
```swift
.background(
    ZStack {
        // Base layer
        Color(nsColor: .windowBackgroundColor)
            .opacity(X)
        
        // Gradient overlay
        LinearGradient(
            colors: [/* color variations */],
            startPoint: /* direction */,
            endPoint: /* direction */
        )
    }
)
```

### Card Header Pattern
```swift
VStack(spacing: 0) {
    // Header
    HeaderContent()
        .padding(20)
        .background(Color.blue.opacity(0.02))
    
    Divider()
    
    // Body
    BodyContent()
        .padding(20)
}
.glassEffect()
```

This creates a sophisticated, layered design that guides user attention while maintaining excellent readability.