// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/
#if !os(tvOS)

import XCTest
import AudioKit
import CAudioKitEX
import AudioKitEX

class NoteEventSequenceTests: XCTestCase {

    func testAdd() {
        var seq = NoteEventSequence()

        seq.add(noteNumber: 60, position: 1.0, duration: 1.0)

        var newNote = SequenceNote()

        newNote.noteOn.status = noteOnByte
        newNote.noteOn.data1 = 60
        newNote.noteOn.data2 = 127
        newNote.noteOn.beat = 1.0

        newNote.noteOff.status = noteOffByte
        newNote.noteOff.data1 = 60
        newNote.noteOff.data2 = 127
        newNote.noteOff.beat = 2.0
        
        XCTAssertEqual(seq, NoteEventSequence(notes: [newNote], events: [], totalDuration: 1.0))
    }

    func testRemoveNote() {

        var seq = NoteEventSequence()
        seq.add(noteNumber: 60, position: 0, duration: 0.1)
        seq.add(noteNumber: 62, position: 0.1, duration: 0.1)
        seq.add(noteNumber: 63, position: 0.2, duration: 0.1)
        seq.removeNote(at: 0.1)

        XCTAssertEqual(seq.notes.count, 2)
    }

    func testRemoveInstances() {

        var seq = NoteEventSequence()
        seq.add(noteNumber: 60, position: 0, duration: 0.1)
        seq.add(noteNumber: 62, position: 0.1, duration: 0.1)
        seq.add(noteNumber: 63, position: 0.2, duration: 0.1)
        seq.removeAllInstancesOf(noteNumber: 63)

        XCTAssertEqual(seq.notes.count, 2)
        XCTAssertEqual(seq.notes[0].noteOn.data1, 60)
        XCTAssertEqual(seq.notes[1].noteOn.data1, 62)
    }

    func testNoteOffAlwaysBeforeNoteOnInBeatTimeOrdered() {
        let noteOn = SequenceEvent(status: noteOnByte, data1: 60, data2: 0, beat: 0)
        let noteOff = SequenceEvent(status: noteOffByte, data1: 60, data2: 0, beat: 0)
        let otherNoteOn = SequenceEvent(status: noteOnByte, data1: 61, data2: 0, beat: 0)

        let sequences = [
            [noteOn, noteOff, otherNoteOn],
            [noteOn, otherNoteOn, noteOff],
            [noteOff, noteOn , otherNoteOn],
            [noteOff, otherNoteOn, noteOn],
            [otherNoteOn, noteOn, noteOff],
            [otherNoteOn, noteOff, noteOn]
        ]

        for sequence in sequences {
            let ordered = sequence.beatTimeOrdered()
            XCTAssertLessThan(ordered.firstIndex(of: noteOff)!, ordered.firstIndex(of: noteOn)!)
        }
    }

    func testEarlierNoteBeforeInBeatTimeOrderedForSameNoteSameStatus() {
        let earlier = SequenceEvent(status: noteOnByte, data1: 60, data2: 0, beat: 0)
        let later = SequenceEvent(status: noteOnByte, data1: 60, data2: 0, beat: 1)

        let sequences = [
            [earlier, later],
            [later, earlier],
        ]

        for sequence in sequences {
            let ordered = sequence.beatTimeOrdered()
            XCTAssertLessThan(ordered.firstIndex(of: earlier)!, ordered.firstIndex(of: later)!)
        }
    }

    func testEarlierNoteBeforeInBeatTimeOrderedForSameNoteDifferentStatus() {
        let earlier = SequenceEvent(status: noteOnByte, data1: 60, data2: 0, beat: 0)
        let later = SequenceEvent(status: noteOffByte, data1: 60, data2: 0, beat: 1)

        let sequences = [
            [earlier, later],
            [later, earlier],
        ]

        for sequence in sequences {
            let ordered = sequence.beatTimeOrdered()
            XCTAssertLessThan(ordered.firstIndex(of: earlier)!, ordered.firstIndex(of: later)!)
        }
    }

}
#endif
