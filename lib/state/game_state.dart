import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/history_record.dart';
import '../data/history_store.dart';
import '../data/puzzle.dart';
import '../data/technique_library.dart';
import '../engine/grid.dart';
import '../engine/hint.dart';
import '../engine/step.dart';
import 'settings.dart';

enum EntryMode { fill, candidate }

/// What the hint overlay is currently showing.
enum HintPhase { none, teaching, current }

/// A render-ready hint: the board to draw, its candidates, and the active
/// technique's explanation stages.
class HintView {
  final String strategyName;
  final String description;
  final List<int> values;
  final List<int> candidates;
  final List<HintStage> stages;
  final bool onCurrentBoard;
  final bool canApply;
  final bool showBoard;

  const HintView({
    required this.strategyName,
    required this.description,
    required this.values,
    required this.candidates,
    required this.stages,
    required this.onCurrentBoard,
    required this.canApply,
    this.showBoard = true,
  });
}

class GameState extends ChangeNotifier {
  static const savedGameKey = 'saved_game_v1';

  final Puzzle puzzle;
  final Settings settings;
  final HistoryStore history;
  final TechniqueLibrary library;
  final SharedPreferences prefs;

  final List<int> givens;
  final List<int> solutionValues;
  final List<int> entries;

  // Two independent note layers, each a list of 9-bit masks per cell.
  // `_manual` holds the player's hand-entered pencil marks; `_auto` holds the
  // set produced by "Notes fill". `notesFillActive` selects which layer is
  // shown and edited — both are preserved so the player can switch freely.
  final List<int> _manual;
  final List<int> _auto;
  bool notesFillActive = false;
  bool _autoFilled = false; // whether `_auto` has been computed at least once

  /// The currently active note layer. Reads and edits flow to this list, so
  /// existing UI and hint code transparently see the layer the player chose.
  List<int> get candidates => notesFillActive ? _auto : _manual;

  int? selectedCell;
  EntryMode mode = EntryMode.fill;

  // Auto-entry: when on, the pad selects a "pen" digit instead of writing it,
  // and tapping a cell applies that digit (in the current mode) automatically.
  bool autoEntry = false;
  int? penDigit;
  int hintsUsed = 0;
  int elapsedSeconds = 0;
  bool paused = false;
  bool solved = false;
  final Set<int> wrongCells = {};

  final List<_Snapshot> _undo = [];
  final List<_Snapshot> _redo = [];

  // Hint controller.
  HintPhase hintPhase = HintPhase.none;
  HintView? hintView;
  int hintStageIndex = 0;
  SolveStep? _pendingStep; // the step to apply on the current board

  GameState({
    required this.puzzle,
    required this.settings,
    required this.history,
    required this.library,
    required this.prefs,
    List<int>? savedEntries,
    List<int>? savedCandidates,
    List<int>? savedAutoCandidates,
    bool savedNotesFillActive = false,
    int savedHints = 0,
    int savedElapsed = 0,
  })  : givens = puzzle.givenValues,
        solutionValues = puzzle.solutionValues,
        entries = savedEntries ?? puzzle.givenValues,
        _manual = savedCandidates ?? List<int>.filled(cellCount, 0),
        _auto = savedAutoCandidates ?? List<int>.filled(cellCount, 0),
        notesFillActive = savedNotesFillActive,
        _autoFilled = savedAutoCandidates != null,
        hintsUsed = savedHints,
        elapsedSeconds = savedElapsed {
    solved = _isWin();
    _recordAttempt();
    _lastAutoPrune = settings.autoPrune;
    settings.addListener(_onSettingsChanged);
  }

  late bool _lastAutoPrune;

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// When auto-prune is switched on, retroactively clear every note that
  /// conflicts with a placed value so the board matches the new setting.
  void _onSettingsChanged() {
    if (settings.autoPrune && !_lastAutoPrune) {
      pruneAllCandidates();
    }
    _lastAutoPrune = settings.autoPrune;
  }

  /// Remove, from both note layers, any candidate that a peer already holds as
  /// a placed value.
  void pruneAllCandidates() {
    final manual = List<int>.from(_manual);
    final auto = List<int>.from(_auto);
    for (var cell = 0; cell < cellCount; cell++) {
      final digit = entries[cell];
      if (digit == 0) continue;
      for (final p in peers[cell]) {
        manual[p] &= ~maskOf(digit);
        auto[p] &= ~maskOf(digit);
      }
    }
    final changed = !listEquals(manual, _manual) || !listEquals(auto, _auto);
    if (!changed) return;
    _pushUndo();
    _manual.setAll(0, manual);
    _auto.setAll(0, auto);
    _afterChange();
  }

  bool get isGiven => false; // helper unused; see givenAt
  bool givenAt(int i) => givens[i] != 0;
  bool get running => !solved && !paused;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  // ---- Selection ----------------------------------------------------------
  void selectCell(int i) {
    selectedCell = i;
    if (autoEntry && penDigit != null) {
      _applyDigit(i, penDigit!);
      return; // _applyDigit notifies
    }
    notifyListeners();
  }

  /// Toggle auto-entry. Clears the held pen digit when switching off.
  void toggleAutoEntry() {
    autoEntry = !autoEntry;
    if (!autoEntry) penDigit = null;
    notifyListeners();
  }

  /// Pick (or unpick) the pen digit used by auto-entry.
  void selectPenDigit(int digit) {
    penDigit = penDigit == digit ? null : digit;
    notifyListeners();
  }

  // ---- Mutation -----------------------------------------------------------
  void _pushUndo() {
    _undo.add(_snapshot());
    if (_undo.length > 200) _undo.removeAt(0);
    _redo.clear();
  }

  _Snapshot _snapshot() => _Snapshot(
        List<int>.from(entries),
        List<int>.from(_manual),
        List<int>.from(_auto),
        notesFillActive,
        _autoFilled,
      );

  void toggleMode() {
    mode = mode == EntryMode.fill ? EntryMode.candidate : EntryMode.fill;
    notifyListeners();
  }

  void setMode(EntryMode m) {
    mode = m;
    notifyListeners();
  }

  void inputDigit(int digit) {
    final cell = selectedCell;
    if (cell == null) return;
    _applyDigit(cell, digit);
  }

  void _applyDigit(int cell, int digit) {
    if (givenAt(cell)) return;
    _pushUndo();
    if (mode == EntryMode.fill) {
      if (entries[cell] == digit) {
        entries[cell] = 0; // toggle off
      } else {
        entries[cell] = digit;
        // A placed value clears notes in that cell across both layers.
        _manual[cell] = 0;
        _auto[cell] = 0;
        if (settings.autoPrune) {
          for (final p in peers[cell]) {
            _manual[p] &= ~maskOf(digit);
            _auto[p] &= ~maskOf(digit);
          }
        }
      }
      wrongCells.remove(cell);
    } else {
      // Candidate toggle — only meaningful on empty cells. Edits the active
      // note layer so the player can annotate either set independently.
      if (entries[cell] == 0) {
        candidates[cell] ^= maskOf(digit);
      }
    }
    _afterChange();
  }

  void erase() {
    final cell = selectedCell;
    if (cell == null || givenAt(cell)) return;
    _pushUndo();
    entries[cell] = 0;
    _manual[cell] = 0;
    _auto[cell] = 0;
    wrongCells.remove(cell);
    _afterChange();
  }

  /// Toggle between the manual notes and the auto-filled notes. The first time
  /// the auto layer is shown it is populated from the current board; afterwards
  /// the player's edits to either layer are preserved across toggles.
  void toggleNotesFill() {
    _pushUndo();
    notesFillActive = !notesFillActive;
    if (notesFillActive && !_autoFilled) {
      final g = CandidateGrid.fromValues(entries);
      for (var i = 0; i < cellCount; i++) {
        _auto[i] = entries[i] == 0 ? g.cands[i] : 0;
      }
      _autoFilled = true;
    }
    _afterChange();
  }

  void reset() {
    _pushUndo();
    for (var i = 0; i < cellCount; i++) {
      entries[i] = givens[i];
      _manual[i] = 0;
      _auto[i] = 0;
    }
    notesFillActive = false;
    _autoFilled = false;
    wrongCells.clear();
    solved = false;
    _afterChange();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot());
    final snap = _undo.removeLast();
    _restore(snap);
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot());
    final snap = _redo.removeLast();
    _restore(snap);
  }

  void _restore(_Snapshot snap) {
    for (var i = 0; i < cellCount; i++) {
      entries[i] = snap.entries[i];
      _manual[i] = snap.manual[i];
      _auto[i] = snap.auto[i];
    }
    notesFillActive = snap.notesFillActive;
    _autoFilled = snap.autoFilled;
    wrongCells.clear();
    solved = _isWin();
    _afterChange();
  }

  /// Highlight entries that disagree with the solution.
  /// Returns the number of incorrect entries found.
  int check() {
    wrongCells.clear();
    for (var i = 0; i < cellCount; i++) {
      if (entries[i] != 0 && entries[i] != solutionValues[i]) {
        wrongCells.add(i);
      }
    }
    notifyListeners();
    return wrongCells.length;
  }

  // ---- Timer --------------------------------------------------------------
  void tickSecond() {
    if (!running) return;
    elapsedSeconds++;
    _save();
    notifyListeners();
  }

  void togglePause() {
    paused = !paused;
    notifyListeners();
  }

  // ---- Hint controller ----------------------------------------------------
  void requestHint() {
    if (solved) return;
    switch (hintPhase) {
      case HintPhase.none:
        // A hint must build on annotations that can still reach the solution:
        // no wrong entries, and every empty cell's notes containing the digit
        // the cell will eventually hold. Otherwise any technique the solver
        // finds rests on impossible premises, so report the problem instead.
        if (_hasWrongEntry()) {
          _showMessageHint(
            name: 'Incorrect entry',
            description: 'One of your solved cells is wrong.',
            text: "One of the numbers you've filled in doesn't match the "
                'solution. Find and fix it (Check marks wrong entries in red), '
                'then ask for a hint again.',
          );
          return;
        }
        if (!_solutionFullyNoted()) {
          // Distinguish two causes: a noted cell whose marks rule out the very
          // digit it will eventually hold, versus cells simply not annotated
          // yet. Either way the solver can't make progress until it's fixed.
          final missingRequired = _notedCellMissingSolution();
          _showMessageHint(
            name: missingRequired
                ? 'Missing required candidates'
                : 'Add more notes',
            description:
                'Fill in more candidate notes so a technique becomes visible.',
            text: missingRequired
                ? "Some cells don't yet contain the digit they'll "
                    'eventually hold, so the solver can\'t make progress. '
                    'Fill in the missing candidates to unlock more hints.'
                : 'Hints work from your pencil marks: every empty cell needs '
                    'notes that include its true digit. Add notes to the '
                    'cells that have none to unlock a hint.',
          );
          return;
        }
        var step = nextHint(entries, candidates);
        if (step == null) {
          _showMessageHint(
            name: 'Add more notes',
            description:
                'Fill in more candidate notes so a technique becomes visible.',
            text: 'No technique applies with your current notes. Add more '
                'pencil marks to unlock a hint.',
          );
          return;
        }
        var info = library.byId(step.strategyId);
        final stepTier = info?.tier ?? tierForRank(step.difficultyRank);
        if (stepTier.index > puzzle.difficulty.index) {
          // The only move the player's notes expose is harder than the
          // puzzle's rated difficulty — usually stale notes hiding the
          // intended line. Prefer teaching a within-difficulty strategy that
          // removes some of the player's existing notes; failing that, if a
          // fuller candidate grid would reveal a strictly easier technique,
          // nudge them to add notes rather than teach the hard one.
          final removal = noteRemovalHint(entries, candidates, puzzle.difficulty);
          if (removal != null) {
            step = removal;
            info = library.byId(step.strategyId);
          } else {
            final fullStep = nextHint(entries);
            final fullTier = fullStep == null
                ? null
                : (library.byId(fullStep.strategyId)?.tier ??
                    tierForRank(fullStep.difficultyRank));
            if (fullTier != null && fullTier.index < stepTier.index) {
              _showMessageHint(
                name: 'Easier move available',
                description:
                    'Filling in more candidate notes reveals an easier strategy.',
                text:
                    'Your notes only reveal a ${stepTier.label.toLowerCase()} '
                    'technique (${info?.name ?? step.strategyName}), but this '
                    'is a ${puzzle.difficulty.label.toLowerCase()} puzzle. Fill '
                    'in more pencil marks to unlock an easier strategy.',
              );
              return;
            }
          }
        }
        _pendingStep = step;
        hintsUsed++;
        if (info != null && info.hasExample) {
          final exampleValues = info.exampleValues;
          final example = runStrategyExample(step.strategyId, exampleValues);
          hintView = HintView(
            strategyName: info.name,
            description: info.description,
            values: exampleValues,
            candidates: example.candidates,
            stages: example.step?.stages ?? const [],
            onCurrentBoard: false,
            canApply: false,
          );
          hintPhase = HintPhase.teaching;
        } else {
          // No example to teach with — go straight to the current board.
          _showCurrentHint(info?.name ?? step.strategyName,
              info?.description ?? '', step);
        }
        hintStageIndex = 0;
        _save();
        notifyListeners();
        break;
      case HintPhase.teaching:
        final step = _pendingStep;
        if (step == null) return;
        final info = library.byId(step.strategyId);
        _showCurrentHint(
            info?.name ?? step.strategyName, info?.description ?? '', step);
        hintStageIndex = 0;
        notifyListeners();
        break;
      case HintPhase.current:
        // Already on current board — restart the hint cycle.
        closeHint();
        requestHint();
        break;
    }
  }

  void _showCurrentHint(String name, String desc, SolveStep step) {
    hintView = HintView(
      strategyName: name,
      description: desc,
      values: List<int>.from(entries),
      candidates: _displayCandidates(entries, candidates),
      stages: step.stages,
      onCurrentBoard: true,
      canApply: step.placements.isNotEmpty || step.eliminations.isNotEmpty,
    );
    hintPhase = HintPhase.current;
  }

  void nextHintStage() {
    final v = hintView;
    if (v == null) return;
    if (hintStageIndex < v.stages.length - 1) {
      hintStageIndex++;
      notifyListeners();
    }
  }

  void prevHintStage() {
    if (hintStageIndex > 0) {
      hintStageIndex--;
      notifyListeners();
    }
  }

  void applyHint() {
    final step = _pendingStep;
    if (step == null) return;
    _pushUndo();
    for (final p in step.placements) {
      if (!givenAt(p.cell)) {
        entries[p.cell] = p.digit;
        _manual[p.cell] = 0;
        _auto[p.cell] = 0;
        if (settings.autoPrune) {
          for (final peer in peers[p.cell]) {
            _manual[peer] &= ~maskOf(p.digit);
            _auto[peer] &= ~maskOf(p.digit);
          }
        }
      }
    }
    for (final e in step.eliminations) {
      _manual[e.cell] &= ~maskOf(e.digit);
      _auto[e.cell] &= ~maskOf(e.digit);
    }
    closeHint();
    _afterChange();
  }

  void closeHint() {
    hintPhase = HintPhase.none;
    hintView = null;
    _pendingStep = null;
    hintStageIndex = 0;
    notifyListeners();
  }

  /// Show an informational hint overlay: a message with no board and no
  /// applicable move, used when the board state blocks a real hint.
  void _showMessageHint({
    required String name,
    required String description,
    required String text,
  }) {
    hintView = HintView(
      strategyName: name,
      description: description,
      values: List<int>.from(entries),
      candidates: _displayCandidates(entries, candidates),
      stages: [HintStage(text: text)],
      onCurrentBoard: true,
      canApply: false,
      showBoard: false,
    );
    hintPhase = HintPhase.current;
    hintStageIndex = 0;
    notifyListeners();
  }

  /// True if any filled cell disagrees with the solution. Givens always match,
  /// so only player entries can be wrong.
  bool _hasWrongEntry() {
    for (var i = 0; i < cellCount; i++) {
      if (entries[i] != 0 && entries[i] != solutionValues[i]) return true;
    }
    return false;
  }

  /// True when some annotated empty cell's notes exclude the digit it holds in
  /// the solution — a stronger signal than a merely un-annotated cell, since
  /// the player has positively ruled out the one digit that must go there.
  bool _notedCellMissingSolution() {
    for (var i = 0; i < cellCount; i++) {
      if (entries[i] != 0 || candidates[i] == 0) continue;
      if (!maskHas(candidates[i], solutionValues[i])) return true;
    }
    return false;
  }

  /// True when every empty cell's notes already include the digit it will hold
  /// in the solution (filled cells are treated as already satisfied). Hints are
  /// derived solely from the player's pencil marks, so a missing solution
  /// candidate blocks the solver from ever placing that cell.
  bool _solutionFullyNoted() {
    for (var i = 0; i < cellCount; i++) {
      if (entries[i] != 0) continue;
      if (!maskHas(candidates[i], solutionValues[i])) return false;
    }
    return true;
  }

  /// Candidates to render on the current-board hint: only the player's own
  /// pencil marks, intersected with basic elimination so an impossible stray
  /// mark isn't shown. Un-annotated cells render empty. Mirrors the set the
  /// hint engine analyses so highlighted cells line up with the player's notes.
  List<int> _displayCandidates(List<int> values, List<int> notes) {
    final g = CandidateGrid.fromValues(values);
    for (var i = 0; i < cellCount; i++) {
      if (values[i] == 0) g.cands[i] &= notes[i];
    }
    return List<int>.from(g.cands);
  }

  // ---- Win / persistence --------------------------------------------------
  void _afterChange() {
    final wasSolved = solved;
    solved = _isWin();
    if (solved && !wasSolved) {
      _recordCompletion();
    }
    _save();
    notifyListeners();
  }

  bool _isWin() {
    for (var i = 0; i < cellCount; i++) {
      if (entries[i] != solutionValues[i]) return false;
    }
    return true;
  }

  void _recordAttempt() {
    final existing = history.forCode(puzzle.code);
    if (existing == null) {
      history.upsert(HistoryRecord(
        code: puzzle.code,
        difficulty: puzzle.difficulty,
        startedAt: DateTime.now(),
      ));
    }
  }

  void _recordCompletion() {
    final existing = history.forCode(puzzle.code);
    final started = existing?.startedAt ?? DateTime.now();
    history.upsert(HistoryRecord(
      code: puzzle.code,
      difficulty: puzzle.difficulty,
      startedAt: started,
      completedAt: DateTime.now(),
      elapsedSeconds: elapsedSeconds,
      hintsUsed: hintsUsed,
    ));
    prefs.remove(savedGameKey); // clear in-progress save once finished
  }

  void _save() {
    if (solved) return;
    prefs.setString(
      savedGameKey,
      jsonEncode({
        'puzzle': puzzle.toJson(),
        'entries': entries,
        'candidates': _manual,
        'autoCandidates': _autoFilled ? _auto : null,
        'notesFillActive': notesFillActive,
        'hintsUsed': hintsUsed,
        'elapsedSeconds': elapsedSeconds,
      }),
    );
  }
}

class _Snapshot {
  final List<int> entries;
  final List<int> manual;
  final List<int> auto;
  final bool notesFillActive;
  final bool autoFilled;
  _Snapshot(
    this.entries,
    this.manual,
    this.auto,
    this.notesFillActive,
    this.autoFilled,
  );
}

/// Reads the saved in-progress puzzle (if any) without building a full game.
Puzzle? savedGamePuzzle(SharedPreferences prefs) {
  final raw = prefs.getString(GameState.savedGameKey);
  if (raw == null) return null;
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return Puzzle.fromJson(Map<String, dynamic>.from(j['puzzle'] as Map));
  } catch (_) {
    return null;
  }
}

/// Rebuilds a [GameState] from the saved in-progress game, or null if none.
GameState? restoreSavedGame({
  required SharedPreferences prefs,
  required Settings settings,
  required HistoryStore history,
  required TechniqueLibrary library,
}) {
  final raw = prefs.getString(GameState.savedGameKey);
  if (raw == null) return null;
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final puzzle = Puzzle.fromJson(Map<String, dynamic>.from(j['puzzle'] as Map));
    return GameState(
      puzzle: puzzle,
      settings: settings,
      history: history,
      library: library,
      prefs: prefs,
      savedEntries: List<int>.from(j['entries'] as List),
      savedCandidates: List<int>.from(j['candidates'] as List),
      savedAutoCandidates: j['autoCandidates'] == null
          ? null
          : List<int>.from(j['autoCandidates'] as List),
      savedNotesFillActive: (j['notesFillActive'] as bool?) ?? false,
      savedHints: (j['hintsUsed'] as num?)?.toInt() ?? 0,
      savedElapsed: (j['elapsedSeconds'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return null;
  }
}
