import copy
import enum
from collections import namedtuple
import numpy as np

__all__ = [
    'Board',
    'GameState',
    'Move',
]

class Point(namedtuple('Point', 'row col')):
    def neighbors(self):
        return [
            Point(self.row - 1, self.col),
            Point(self.row + 1, self.col),
            Point(self.row, self.col - 1),
            Point(self.row, self.col + 1)
        ]
    
    def to_idx(self):
        return 13 * (self.row - 1) + (self.col - 1)

class Move():
    # optional expansions: resigning, draws etc.
    def __init__(self, point):
        assert (point is not None)
        self.point = point
        self.is_play = (self.point is not None)
    
    @classmethod
    def play(cls, point):
        return Move(point=point)

class Player(enum.Enum):
    red = 1
    yellow = 2

    @property
    def other(self):
        return Player.red if self == Player.yellow else Player.yellow

class Board():
    def __init__(self):
        self.num_rows = 6
        self.num_cols = 13
        self.reds = np.zeros(78, dtype=bool)
        self.yellows = np.zeros(78, dtype=bool)
        self.open_spaces = 61
        self.last_move = None

    def print_board(self, winning_canoes=None):
        print("")
        counter = 0
        for r in range(1, self.num_rows + 1):
            for c in range(1, self.num_cols + 1):
                pt = Point(r, c)
                symbol = "□"
                if winning_canoes is not None:
                    if counter in winning_canoes[0] or counter in winning_canoes[1]:
                        symbol = "■"
                if not self.is_on_grid(pt):
                    print("  ", end=" ")
                elif self.reds[counter]:
                    print(f"\033[91m {symbol}\033[0m", end=" ")
                elif self.yellows[counter]:
                    print(f"\033[93m {symbol}\033[0m", end=" ")
                else:
                    print(f"{counter:02d}\033[0m", end=" ")
                counter += 1
            print("")
        print("")
        
    def place_peg(self, player, point):
        assert self.is_on_grid(point)
        assert self.get(point) is None
        if player == Player.red:
            self.reds[point.to_idx()] = True
        else:
            self.yellows[point.to_idx()] = True
        self.last_move = point
        self.open_spaces -= 1

    def return_open_spaces(self):
        open_spaces = []
        for r in range(1, self.num_rows + 1):
            for c in range(1, self.num_cols + 1):
                pt = Point(r, c)
                if self.is_on_grid(pt) and self.get(pt) is None:
                    open_spaces.append(pt)
        return open_spaces
        
    def is_on_grid(self, point):
        idx = point.to_idx()
        if idx in [0, 3, 4, 5, 6, 7, 8, 9, 12, 52, 64, 65, 66, 67, 75, 76, 77]:
            return False
        return 1 <= point.row <= self.num_rows and 1 <= point.col <= self.num_cols

    def get(self, point):
        if self.reds[point.to_idx()]:
            return Player.red
        elif self.yellows[point.to_idx()]:
            return Player.yellow
        else:
            return None

    def __deepcopy__(self, memodict={}):
        copied = Board()
        copied.reds = np.copy(self.reds)
        copied.yellows = np.copy(self.yellows)
        copied.open_spaces = np.copy(self.open_spaces)
        return copied

b = Board()
solns = []
print("Initializing Canoe AI: building solutions...")
for r in range(1, b.num_rows): # \__/
    for c in range(1, b.num_cols):
        if False not in (b.is_on_grid(Point(r, c)), b.is_on_grid(Point(r, c+3)), b.is_on_grid(Point(r+1, c+1)), b.is_on_grid(Point(r+1, c+2))):
            solns.append( (Point(r, c).to_idx(), Point(r, c+3).to_idx(), Point(r+1, c+1).to_idx(), Point(r+1, c+2).to_idx() ) )
for r in range(1, b.num_rows): # /~~\
    for c in range(1, b.num_cols):
        if False not in ( b.is_on_grid(Point(r, c+1)),  b.is_on_grid(Point(r, c+2)),  b.is_on_grid(Point(r+1, c)),  b.is_on_grid(Point(r+1, c+3))):
            solns.append( ( Point(r, c+1).to_idx(),  Point(r, c+2).to_idx(),  Point(r+1, c).to_idx(),  Point(r+1, c+3).to_idx()) )
for r in range(1, b.num_rows): # (
    for c in range(1, b.num_cols):
        if False not in (b.is_on_grid(Point(r, c+1)), b.is_on_grid(Point(r+1, c)), b.is_on_grid(Point(r+2, c)), b.is_on_grid(Point(r+3, c+1))):
            solns.append( (Point(r, c+1).to_idx(), Point(r+1, c).to_idx(), Point(r+2, c).to_idx(), Point(r+3, c+1).to_idx()) )
for r in range(1, b.num_rows): # )
    for c in range(1, b.num_cols):
        if False not in (b.is_on_grid(Point(r, c)), b.is_on_grid(Point(r+1, c+1)), b.is_on_grid(Point(r+2, c+1)), b.is_on_grid(Point(r+3, c))):
            solns.append( (Point(r, c).to_idx(), Point(r+1, c+1).to_idx(), Point(r+2, c+1).to_idx(), Point(r+3, c).to_idx()) )
soln_counter = 0
solns_dict = {}
for idx in range(78):
    solns_dict[idx] = []
    for soln in solns:
        if idx in soln:
            tuple3 = tuple([el for el in soln if el != idx])
            solns_dict[idx].append(tuple3)
            soln_counter += 1
print(f"There are {soln_counter} canoes.")

class GameState():
    def __init__(self, board, current_player, previous, move):
        self.board = board
        self.current_player = current_player
        self.previous_state = previous
        self.last_move = move
        self.winner = None
        self.winning_canoes = None
        self.solns = solns
        self.solns_dict = solns_dict
        
    def print_board(self):
        self.board.print_board(self.winning_canoes)

    def apply_move(self, move):
        if move.is_play:
            next_board = copy.deepcopy(self.board)
            next_board.place_peg(self.current_player, move.point)
        return GameState(next_board, self.current_player.other, self, move)


    def completes_canoe(self, pt, player):
        if player == Player.red:
            moves = self.board.reds
        else:
            moves = self.board.yellows
        pt_idx = pt.to_idx()
        for s in self.solns_dict[pt_idx]:
            if all(moves[elem] for elem in s):
                return True
            else:
                pass
        return False

    def is_over(self):
        if self.last_move is None:
            return False
        if self.board.open_spaces <= 0:
            self.winner = 0
            return True
        if self.current_player.other == Player.red: # apply_move just called by current_player.other
            moves = self.board.reds
            winner = self.current_player.other
        else:
            moves = self.board.yellows
            winner = self.current_player.other
        last_move_id = self.last_move.point.to_idx()
        for s in self.solns_dict[last_move_id]:
            if all(moves[elem] for elem in s):
                new_canoe = True
                break
            else:
                new_canoe = False
        if new_canoe:
            canoes = []
            for s in self.solns:
                if all(moves[elem] for elem in s):
                    canoes.append(s)
            if len(canoes) >= 2:
                for c1 in canoes:
                    for c2 in canoes:
                        if not any(cc in c2 for cc in c1):
                            self.winner = winner
                            self.winning_canoes = [c1, c2]
                            return True
        return False

    def legal_moves(self):
        return [ Move.play(pt) for pt in self.board.return_open_spaces() ]

    def is_valid_move(self, move):
        if self.is_over():
            return False
        return self.board.get(move.point) is None and self.board.is_on_grid(move.point)

    @classmethod
    def new_game(cls, first_player = Player.red):
        board = Board()
        return GameState(board, first_player, None, None)

def print_error(msg):
    print(f"\033[92m{msg}\033[0m")
    
def print_colored(turn, msg):
    if turn == 0:
        print(f"{msg}")
    elif turn == 1:
        print(f"\033[91m{msg}\033[0m")
    elif turn == 2:
        print(f"\033[93m{msg}\033[0m")
