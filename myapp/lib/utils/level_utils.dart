import 'dart:math';

int levelFromXp(int xp) => xp <= 0 ? 0 : sqrt(xp / 100).floor();

int xpForLevel(int level) => level * level * 100;

// XP earned within the current level
int xpIntoLevel(int xp) => xp - xpForLevel(levelFromXp(xp));

// XP needed to reach the next level from the start of the current one
int xpNeededForLevel(int xp) {
  final level = levelFromXp(xp);
  return xpForLevel(level + 1) - xpForLevel(level);
}

// Progress from 0.0 → 1.0 within the current level
double levelProgress(int xp) {
  final needed = xpNeededForLevel(xp);
  return needed == 0 ? 1.0 : xpIntoLevel(xp) / needed;
}
