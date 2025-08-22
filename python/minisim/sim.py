from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Tuple, TypedDict
import multiprocessing as mp
import time


class Stats(TypedDict):
    total_agents: int
    vote_results: Dict[int, int]
    average_preferences: List[float]
    agent_preferences: List[List[float]]


@dataclass
class Agent:
    rho: float
    pi: float
    preferences: List[float]


class Rng:
    """64-bit LCG matching Elixir implementation.
    state_{n+1} = (a * state_n + c) mod 2^64
    uniform = state / 2^64
    """

    MOD = 1 << 64
    A = 636_413_622_384_679_300_5
    C = 1_442_695_040_888_963_407

    def __init__(self, seed: int) -> None:
        s = seed % self.MOD
        self.state = s if s >= 0 else s + self.MOD

    def next(self) -> int:
        self.state = (self.A * self.state + self.C) % self.MOD
        return self.state

    def uniform(self) -> float:
        s = self.next()
        return s / self.MOD


def _locate(from_pair: Tuple[int, int], to_pair: Tuple[int, int]) -> Tuple[int, int]:
    (from_va, from_vb) = from_pair
    (to_va, to_vb) = to_pair
    from_idx = (from_va - 1) * 3 + (from_vb - 1)
    to_idx = (to_va - 1) * 3 + (to_vb - 1)
    return from_idx, to_idx


def _normalize_triple(a: float, b: float, c: float) -> Tuple[float, float, float]:
    total = a + b + c
    if total <= 0:
        return (1.0 / 3, 1.0 / 3, 1.0 / 3)
    return a / total, b / total, c / total


def _choice_probabilities(resistance: float, persuasion: float) -> Tuple[float, float, float]:
    keep = resistance * (1 - persuasion)
    change = (1 - resistance) * persuasion
    alt = resistance * persuasion
    return _normalize_triple(keep, change, alt)


def _build_disagreement_map(va: int, vb: int, alice_probs: Tuple[float, float, float], bob_probs: Tuple[float, float, float]):
    pa1, pa2, pa3 = alice_probs
    pb1, pb2, pb3 = bob_probs
    mapping: Dict[Tuple[int, int], float] = {}
    mapping[_locate((va, vb), (va, vb))] = pa1 * pb1
    mapping[_locate((va, vb), (va, va))] = pa1 * pb2
    mapping[_locate((va, vb), (vb, vb))] = pa2 * pb1
    mapping[_locate((va, vb), (vb, va))] = pa2 * pb2
    mapping[_locate((va, vb), (va, 3))] = pa1 * pb3
    mapping[_locate((va, vb), (3, vb))] = pa3 * pb1
    mapping[_locate((va, vb), (3, 3))] = pa3 * pb3
    mapping[_locate((va, vb), (vb, 3))] = pa2 * pb3
    mapping[_locate((va, vb), (3, va))] = pa3 * pb2
    return mapping


def _transition_matrix(alice: Agent, bob: Agent) -> List[List[float]]:
    alice_probs = _choice_probabilities(alice.rho, bob.pi)
    bob_probs = _choice_probabilities(bob.rho, alice.pi)

    disagreement_12 = _build_disagreement_map(1, 2, alice_probs, bob_probs)
    disagreement_21 = _build_disagreement_map(2, 1, bob_probs, bob_probs)
    disagreements = {**disagreement_12, **disagreement_21}

    mat: List[List[float]] = []
    for row in range(9):
        row_vals: List[float] = []
        for col in range(9):
            if (row, col) in disagreements:
                row_vals.append(disagreements[(row, col)])
            elif row == col:
                row_vals.append(1.0)
            else:
                row_vals.append(0.0)
        mat.append(row_vals)
    return mat


def _talk(alice: Agent, bob: Agent) -> Tuple[List[float], List[float]]:
    # joint preferences (outer product)
    joint = [[a * b for b in bob.preferences] for a in alice.preferences]  # 3x3
    v = [joint[i][j] for i in range(3) for j in range(3)]  # flatten row-major length 9
    T = _transition_matrix(alice, bob)  # 9x9
    # r = v @ T (1x9 * 9x9) => length 9
    r = [sum(v[k] * T[k][j] for k in range(9)) for j in range(9)]
    result = [[r[i * 3 + j] for j in range(3)] for i in range(3)]  # 3x3

    # Alice gets row sums; Bob gets column sums
    alice_vec = [round(sum(result[i]), 3) for i in range(3)]
    bob_vec = [round(sum(result[i][j] for i in range(3)), 3) for j in range(3)]

    a_sum = sum(alice_vec)
    b_sum = sum(bob_vec)
    if a_sum <= 0:
        alice_prefs = [1.0 / 3] * 3
    else:
        alice_prefs = [x / a_sum for x in alice_vec]
    if b_sum <= 0:
        bob_prefs = [1.0 / 3] * 3
    else:
        bob_prefs = [x / b_sum for x in bob_vec]
    return alice_prefs, bob_prefs


def _generate_all_pairs(n: int) -> List[Tuple[int, int]]:
    return [(i, j) for i in range(n - 1) for j in range(i + 1, n)]


def _average_prefs(prefs_list: List[List[float]]) -> List[float]:
    if not prefs_list:
        return [0.0, 0.0, 0.0]
    count = len(prefs_list)
    s0 = sum(p[0] for p in prefs_list)
    s1 = sum(p[1] for p in prefs_list)
    s2 = sum(p[2] for p in prefs_list)
    return [s0 / count, s1 / count, s2 / count]


def _get_statistics(agents: List[Agent]) -> Stats:
    agent_preferences = [[round(p[0], 3), round(p[1], 3), round(p[2], 3)] for p in (a.preferences[:] for a in agents)]
    avg = _average_prefs(agent_preferences)
    avg = [round(x, 3) for x in avg]
    return {
        "total_agents": len(agents),
        "vote_results": {},
        "average_preferences": avg,
        "agent_preferences": agent_preferences,
    }


def _talk_batch(batch: List[Tuple[int, int, Agent, Agent]]) -> List[Tuple[int, List[float]]]:
    """Worker: process a batch of (i,j,ai,aj) and return flattened updates.

    Returns a list like [(i, ai_prefs), (j, aj_prefs), ...].
    """
    out: List[Tuple[int, List[float]]] = []
    for i, j, ai, aj in batch:
        ai_p, aj_p = _talk(ai, aj)
        out.append((i, ai_p))
        out.append((j, aj_p))
    return out


def run(agents: int, iterations: int, seed: int, chunk_size: int, procs: int = 1) -> Stats:
    """
    Python variant of MiniSim.run/4 (no concurrency). Always all-pairs matching per tick.
    """
    assert isinstance(agents, int) and agents > 0
    assert isinstance(iterations, int) and iterations >= 0
    assert isinstance(seed, int)
    assert isinstance(chunk_size, int) and chunk_size > 0
    assert isinstance(procs, int) and procs >= 1

    rng = Rng(seed)

    # Seed agents
    pop: List[Agent] = []
    for _ in range(agents):
        rho = rng.uniform()
        pi = rng.uniform()
        option1_pref = rng.uniform()
        pop.append(Agent(rho=rho, pi=pi, preferences=[option1_pref, 1 - option1_pref, 0.0]))

    # Initial stats (to mirror Elixir's behavior though it returns final)
    stats = _get_statistics(pop)
    # compute votes with portable RNG
    vote_results: Dict[int, int] = {}
    for a in pop:
        u = rng.uniform()
        if u <= a.preferences[0]:
            idx = 0
        elif u <= a.preferences[0] + a.preferences[1]:
            idx = 1
        else:
            idx = 2
        vote_results[idx] = vote_results.get(idx, 0) + 1
    stats["vote_results"] = vote_results

    for _ in range(iterations):
        pairs = _generate_all_pairs(len(pop))
        updates: Dict[int, List[List[float]]] = {}

        if procs <= 1:
            # Sequential path
            for idx in range(0, len(pairs), chunk_size):
                for (i, j) in pairs[idx : idx + chunk_size]:
                    ai, aj = pop[i], pop[j]
                    ai_p, aj_p = _talk(ai, aj)
                    updates.setdefault(i, []).append(ai_p)
                    updates.setdefault(j, []).append(aj_p)
        else:
            # Parallel path: build batches of pairs with their current agent snapshots
            tasks: List[List[Tuple[int, int, Agent, Agent]]] = []
            for idx in range(0, len(pairs), chunk_size):
                batch: List[Tuple[int, int, Agent, Agent]] = []
                for (i, j) in pairs[idx : idx + chunk_size]:
                    batch.append((i, j, pop[i], pop[j]))
                if batch:
                    tasks.append(batch)

            # Use a process pool; avoid huge chunks in imap by keeping chunksize=1
            with mp.get_context("spawn").Pool(processes=procs) as pool:
                for batch_out in pool.imap_unordered(_talk_batch, tasks, chunksize=1):
                    for idx, prefs in batch_out:
                        updates.setdefault(idx, []).append(prefs)

        # Apply averaged updates
        new_pop: List[Agent] = []
        for idx, a in enumerate(pop):
            if idx in updates:
                avg_p = _average_prefs(updates[idx])
                new_pop.append(Agent(rho=a.rho, pi=a.pi, preferences=avg_p))
            else:
                new_pop.append(a)
        pop = new_pop

        stats = _get_statistics(pop)
        # update votes with portable RNG
        vote_results = {}
        for a in pop:
            u = rng.uniform()
            if u <= a.preferences[0]:
                idx = 0
            elif u <= a.preferences[0] + a.preferences[1]:
                idx = 1
            else:
                idx = 2
            vote_results[idx] = vote_results.get(idx, 0) + 1
        stats["vote_results"] = vote_results

    return stats


def sweep(max_agents: int, iterations: int, seed: int, chunk_size: int, procs: int = 1) -> None:
    """Run from 2..max_agents, printing wall ms per run (one per line)."""
    assert isinstance(max_agents, int) and max_agents >= 2
    for n in range(2, max_agents + 1):
        t0 = time.perf_counter()
        _ = run(n, iterations, seed, chunk_size, procs)
        t1 = time.perf_counter()
        ms = int((t1 - t0) * 1000)
        print(ms)
