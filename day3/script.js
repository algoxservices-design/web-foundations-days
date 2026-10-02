let notes = [
  { id: 1, text: "Buy milk and bread", category: "personal" },
  { id: 2, text: "Finish the Day 3 assignment", category: "study" },
  { id: 3, text: "Email the project report to Grace", category: "work" },
  { id: 4, text: "Revise JavaScript arrays", category: "study" },
  { id: 5, text: "Call mum", category: "personal" },
];

function searchNotes(word) {
  const searchWord = word.toLowerCase();

  return notes.filter((note) =>
    note.text.toLowerCase().includes(searchWord)
  );
}

console.log(searchNotes("javascript"));
// Expected: [{ id: 4, text: "Revise JavaScript arrays", category: "study" }]

console.log(searchNotes("python"));
// Expected: []


function longestNote() {
  if (notes.length === 0) {
    return null;
  }

  let longest = notes[0];

  for (let i = 1; i < notes.length; i++) {
    if (notes[i].text.length > longest.text.length) {
      longest = notes[i];
    }
  }

  return longest;
}

console.log(longestNote());
// Expected: { id: 3, text: "Email the project report to Grace", category: "work" }

let savedNotes = notes;
notes = [];

console.log(longestNote());
// Expected: null

notes = savedNotes;


function countByCategory() {
  const counts = {};

  for (const note of notes) {
    if (counts[note.category]) {
      counts[note.category]++;
    } else {
      counts[note.category] = 1;
    }
  }

  return counts;
}

console.log(countByCategory());
// Expected: { personal: 2, study: 2, work: 1 }

let savedNotesForCount = notes;
notes = [];

console.log(countByCategory());
// Expected: {}

notes = savedNotesForCount;


function getSummary() {
  const counts = countByCategory();
  const total = notes.length;

  const noteWord = total === 1 ? "note" : "notes";

  return `${total} ${noteWord}: ${counts.personal || 0} personal, ${counts.work || 0} work, ${counts.study || 0} study.`;
}

console.log(getSummary());
// Expected: 5 notes: 2 personal, 1 work, 2 study.

let savedNotesForSummary = notes;
notes = [notes[0]];

console.log(getSummary());
// Expected: 1 note: 1 personal, 0 work, 0 study.

notes = savedNotesForSummary;


function isDuplicate(text) {
  const normalizedText = text.trim().toLowerCase();

  return notes.some(
    (note) => note.text.trim().toLowerCase() === normalizedText
  );
}

console.log(isDuplicate("Buy milk and bread"));
// Expected: true

console.log(isDuplicate("  BUY MILK AND BREAD  "));
// Expected: true


function addNote(text, category) {
  const trimmedText = text.trim();
  const validCategories = ["personal", "work", "study"];

  if (trimmedText.length < 1 || trimmedText.length > 200) {
    console.log("Note must be between 1 and 200 characters.");
    return false;
  }

  if (isDuplicate(trimmedText)) {
    console.log("Note is a duplicate.");
    return false;
  }

  if (!validCategories.includes(category)) {
    console.log("Invalid category.");
    return false;
  }

  const newNote = {
    id: notes.length > 0 ? Math.max(...notes.map((note) => note.id)) + 1 : 1,
    text: trimmedText,
    category: category,
  };

  notes.push(newNote);

  return true;
}

console.log(addNote("Learn JavaScript functions", "study"));
// Expected: true

console.log(addNote("  BUY MILK AND BREAD  ", "personal"));
// Expected: false
// Reason: Note is a duplicate.

console.log(addNote("Plan weekend activities", "shopping"));
// Expected: false
// Reason: Invalid category.

console.log(addNote("   ", "personal"));
// Expected: false
// Reason: Note must be between 1 and 200 characters.
