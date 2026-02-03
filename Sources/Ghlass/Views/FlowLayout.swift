import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        
        let width = proposal.width ?? rows.map { $0.width }.max() ?? 0
        let height = rows.map { $0.height }.reduce(0, +) + (CGFloat(max(0, rows.count - 1)) * spacing)
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: item.size.width, height: item.size.height))
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }
    
    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }
    
    private struct Item {
        let view: LayoutSubviews.Element
        let size: CGSize
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentRow.width + size.width + (currentRow.items.isEmpty ? 0 : spacing) > maxWidth {
                // New row
                rows.append(currentRow)
                currentRow = Row()
            }
            
            currentRow.items.append(Item(view: subview, size: size))
            currentRow.width += size.width + (currentRow.items.count > 1 ? spacing : 0)
            currentRow.height = max(currentRow.height, size.height)
        }
        
        if !currentRow.items.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
}
