// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKitUI/

import SwiftUI

public struct PianoRollNote: Equatable, Identifiable {
    public init(start: Int, length: Int, pitch: Int) {
        self.start = start
        self.length = length
        self.pitch = pitch
    }

    public var id = UUID()

    /// The start step.
    var start: Int

    /// How many steps long?
    var length: Int

    /// Abstract pitch, not MIDI notes.
    var pitch: Int

}

public struct PianoRollModel: Equatable {
    public init(notes: [PianoRollNote], length: Int, height: Int) {
        self.notes = notes
        self.length = length
        self.height = height
    }

    /// The sequence being edited.
    var notes:[PianoRollNote]

    /// How many steps in the piano roll.
    var length: Int

    /// Maximum pitch.
    var height: Int

}

func sign(_ x: CGFloat) -> CGFloat {
    x > 0 ? 1 : -1
}

struct PianoRollNoteView: View {
    @Binding var note: PianoRollNote
    var gridSize: CGSize
    @State var offset = CGSize.zero
    @State var hovering = false
    @State var lengthOffset: CGFloat = 0
    var sequenceLength: Int
    var sequenceHeight: Int

    func snap() -> PianoRollNote {
        var n = note
        n.start += Int(offset.width / CGFloat(gridSize.width) + sign(offset.width) * 0.5)
        n.start = max(0, n.start)
        n.start = min(sequenceLength - 1, n.start)
        n.pitch += Int(offset.height / CGFloat(gridSize.height) + sign(offset.height) * 0.5)
        n.pitch = max(0, n.pitch)
        n.pitch = min(sequenceHeight - 1, n.pitch)
        n.length += Int(lengthOffset / gridSize.width + sign(lengthOffset) * 0.5 )
        n.length = max(1, n.length)
        n.length = min(sequenceLength, n.length)
        n.length = min(sequenceLength - n.start, n.length)
        return n
    }

    func noteOffset(note: PianoRollNote) -> CGSize {
        CGSize(width: gridSize.width * CGFloat(note.start),
               height: gridSize.height * CGFloat(note.pitch))
    }

    var body: some View {
        if offset != CGSize.zero {
            Rectangle()
                .foregroundColor(.black.opacity(0.2))
                .frame(width: gridSize.width * CGFloat(snap().length),
                       height: gridSize.height)
                .offset(noteOffset(note: snap()))
                .zIndex(-1)
        }

        // Set the minimum distance so a note drag will override
        // the drag of a containing ScrollView.
        let minimumDistance = 2

        let noteDragGesture = DragGesture(minimumDistance: 2)
            .onChanged{ value in
                offset = value.translation
            }
            .onEnded{ value in
                withAnimation(.easeOut) {
                    note = snap()
                    offset = CGSize.zero
                }
            }

        let lengthDragGesture = DragGesture(minimumDistance: 2)
            .onChanged{ value in
                lengthOffset = value.translation.width
            }
            .onEnded{ value in
                withAnimation(.easeOut) {
                    note = snap()
                    lengthOffset = 0
                }
            }

        ZStack(alignment: .trailing) {
            Rectangle()
                .foregroundColor(.cyan.opacity( (hovering || offset != .zero || lengthOffset != 0) ? 1.0 : 0.8))
            Rectangle()
                .foregroundColor(.black)
                .padding(4)
                .frame(width: 10)
        }
            .onHover { over in hovering = over }
            .padding(1) // so we can see consecutive notes
            .frame(width: max(gridSize.width, gridSize.width * CGFloat(note.length) + lengthOffset),
                   height: gridSize.height)
            .offset(x: gridSize.width * CGFloat(note.start) + offset.width,
                    y: gridSize.height * CGFloat(note.pitch) + offset.height)
            .gesture(noteDragGesture)
        HStack() {
            Spacer()
            Rectangle()
                .foregroundColor(.white.opacity(0.001))
                .frame(width: gridSize.width * 0.5, height: gridSize.height)
                .gesture(lengthDragGesture)
        }
        .frame(width: gridSize.width * CGFloat(note.length),
               height: gridSize.height)
        .offset(x: gridSize.width * CGFloat(note.start) + offset.width,
                y: gridSize.height * CGFloat(note.pitch) + offset.height)

    }
}

public struct PianoRoll: View {

    @Binding var model: PianoRollModel
    var gridSize = CGSize(width: 80, height: 40)

    public init(model: Binding<PianoRollModel>) {
        _model = model
    }

    let gridColor = Color(red: 15.0/255.0, green: 17.0/255.0, blue: 16.0/255.0)

    func drawGrid(cx: GraphicsContext, size: CGSize) {
        var x: CGFloat = 0
        for _ in 0 ... model.length {

            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))

            cx.stroke(path, with: .color(gridColor), lineWidth: 0.5)

            x += gridSize.width
        }

        var y: CGFloat = 0
        for _ in 0 ... model.height {

            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))

            cx.stroke(path, with: .color(gridColor), lineWidth: 0.5)

            y += gridSize.height
        }
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            let dragGesture = DragGesture(minimumDistance: 0).onEnded({ value in
                let location = value.location
                let step = Int(location.x / gridSize.width)
                let pitch = Int(location.y / gridSize.height)
                model.notes.append(PianoRollNote(start: step, length: 1, pitch: pitch))
            })
            Canvas { cx, size in
                drawGrid(cx: cx, size: size)
            }.gesture(TapGesture().sequenced(before: dragGesture))
            ForEach(model.notes) { note in
                PianoRollNoteView(
                    note: $model.notes[model.notes.firstIndex(of: note)!],
                    gridSize: gridSize,
                    sequenceLength: model.length,
                    sequenceHeight: model.height)
                .onTapGesture {
                    model.notes.removeAll(where: { $0 == note })
                }
            }
        }.frame(width: CGFloat(model.length) * gridSize.width,
                height: CGFloat(model.height) * gridSize.height)
    }
}

public struct PianoRollTestView: View {

    public init() { }

    @State var model = PianoRollModel(notes: [
        PianoRollNote(start: 1, length: 2, pitch: 3),
        PianoRollNote(start: 5, length: 1, pitch: 4)
    ], length: 128, height: 16)

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            PianoRoll(model: $model)
        }.background(Color(white: 0.1))
    }
}

struct PianoRoll_Previews: PreviewProvider {
    static var previews: some View {
        PianoRollTestView()
    }
}
