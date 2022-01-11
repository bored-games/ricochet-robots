
import numpy as np
import time
import canoebot.agent as agent
import canoebot.encoders as encoders
import canoebot.utils as utils
from canoebot.board import Board, GameState, Player

agent1 = agent.ACAgent(utils.load_model("ac-v12"), encoders.RelativeEncoder())


def xy_to_idx(pt):
    x, y = pt
    return 13*y + x


def canoe_ai(reds, yellows, ai_team):
    player = Player.red if ai_team == 1 else Player.yellow

    reds = [ xy_to_idx(pt) for pt in reds ]
    yellows = [ xy_to_idx(pt) for pt in yellows ]
    new_board = Board()
    
    new_board.reds = np.zeros(78, dtype=bool)
    for x in reds:
        new_board.reds[x] = True
    new_board.yellows = np.zeros(78, dtype=bool)
    for x in yellows:
        new_board.yellows[x] = True

    game = GameState(board = new_board, current_player=player, previous = None, move = None)
    # game.print_board()
    bot_move = agent1.select_move(game)

    x = int(bot_move.point.col - 1)
    y = int(bot_move.point.row - 1)
    print(f"Making a move for {player}, reds: {reds}, yellows: {yellows}: {(x, y)}")
    return (x, y)

def init():
    return None

def main():
    test()

if __name__ == '__main__':
    main()
