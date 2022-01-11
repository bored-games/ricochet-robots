import numpy as np
from canoebot.board import Move, Point
import canoebot.encoders as encoders
from tensorflow.keras.optimizers import SGD

# Optional: disable GPU -- we're only using tensorflow.model.predict()
# import os
# os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

class Agent:
  def __init__(self):
    pass

  def select_move(self, game_state):
    raise NotImplementedError()

class Human(Agent):
  def __init__(self):
    self.encoder_test = encoders.RelativeEncoder()

  def select_move(self, game):
    open_spaces = game.board.return_open_spaces()
    while True:
      human_input = input("Select an index: ")
      try:
        human_input = int(human_input)
        r = human_input // game.board.num_cols
        c = human_input % game.board.num_cols
        pt = Point(row = r+1, col = c+1)
        if pt in open_spaces:
          return Move.play(pt)
        else:
          print("Error. Try again.")
      except:
        board_tensor = self.encoder_test.encode(game)
        print(board_tensor)

    
class RandomAgent(Agent):
  def __init__(self):
    pass

  def select_move(self, game):
    previous_move = game.last_move
    open_spaces = game.board.return_open_spaces()
    return Move.play(open_spaces[np.random.choice(len(open_spaces))])


class NeighborAgent(Agent):
  def __init__(self):
    pass

  def select_move(self, game):
    previous_move = game.last_move
    # print(f"Previous move: {previous_move}")
    if previous_move == None:
      open_spaces = game.board.return_open_spaces()
      return Move.play(open_spaces[np.random.choice(len(open_spaces))])
    
    open_spaces = []
    for r in [previous_move.point.row - 1, previous_move.point.row, previous_move.point.row + 1]:
      for c in [previous_move.point.col - 1, previous_move.point.col, previous_move.point.col + 1]:
        pt = Point(r, c)
        try:
          if game.board.is_on_grid(pt) > 0 and game.board.get(pt) is None:
            open_spaces.append(pt)
        except: pass
    if len(open_spaces) > 0:
      return Move.play(open_spaces[np.random.choice(len(open_spaces))])
    else: # no open neighbors, choose randomly
      open_spaces = game.board.return_open_spaces()
      return Move.play(open_spaces[np.random.choice(len(open_spaces))])

class GreedyAgent(Agent):
  def __init__(self):
    pass

  def select_move(self, game):
    previous_move = game.last_move
    # print(f"Previous move: {previous_move}")
    if previous_move == None:
      open_spaces = game.board.return_open_spaces()
      return Move.play(open_spaces[np.random.choice(len(open_spaces))])
    
    winning_move = self.find_winning_move(game)
    if winning_move:
      return Move.play(winning_move)

    open_spaces = []
    for r in [previous_move.point.row - 1, previous_move.point.row, previous_move.point.row + 1]:
      for c in [previous_move.point.col - 1, previous_move.point.col, previous_move.point.col + 1]:
        pt = Point(r, c)
        try:
          if game.board.is_on_grid(pt) > 0 and game.board.get(pt) is None:
            open_spaces.append(pt)
        except: pass
    if len(open_spaces) == 0:
      open_spaces = game.board.return_open_spaces()
    
    open_spaces = self.remove_losing_moves(game, open_spaces)
    return Move.play(open_spaces[np.random.choice(len(open_spaces))])

  def find_winning_move(self, game):
    for candidate in game.board.return_open_spaces():
      next_state = game.apply_move(Move.play(candidate))
      if next_state.is_over() and next_state.winner == next_state.current_player.other:
        return candidate
    return None
  
  def remove_losing_moves(self, game, open_spaces):
    okay_moves = []
    for candidate in open_spaces:
      next_state = game.apply_move(Move.play(candidate))
      opponent_winning_move = self.find_winning_move(next_state)
      if opponent_winning_move == None:
        okay_moves.append(candidate)
    if len(okay_moves) > 0:
      return okay_moves
    else:
      return open_spaces

class DeepLearningAgent(Agent):
  def __init__(self, model, encoder):
    Agent.__init__(self)
    self.model = model
    self.encoder = encoder

  def predict(self, game_state):
    encoded_state = self.encoder.encode(game_state)
    input_tensor = np.array([encoded_state]) # .reshape(1, 6, 13, 1)
    return self.model.predict(input_tensor)[0]

  def select_move(self, game_state):
    num_moves = self.encoder.board_width * self.encoder.board_height
    move_probs = self.predict(game_state)
    move_probs = move_probs ** 3
    eps = 1e-5
    move_probs = np.clip(move_probs, eps, 1-eps)
    move_probs = move_probs / np.sum(move_probs)
    candidates = np.arange(num_moves)
    ranked_moves = np.random.choice(candidates, num_moves, replace=False, p=move_probs)
    for point_idx in ranked_moves:
      point = self.encoder.decode_point_index(point_idx)
      if game_state.is_valid_move(Move.play(point)):
        return Move.play(point)

class PolicyAgent(Agent):
  def __init__(self, model, encoder):
    self.model = model
    self.encoder = encoder
    self.temperature = 0.0
    self.collector = None

  def set_collector(self, collector):
    self.collector = collector

  def select_move(self, game_state):
    num_moves = self.encoder.board_width * self.encoder.board_height
    board_tensor = self.encoder.encode(game_state)
    X = np.array([board_tensor])

    if np.random.random() < self.temperature:
      move_probs = np.ones(num_moves) / num_moves
    else:
      move_probs = self.model.predict(X)[0]

    # Prevent move probs from getting stuck at 0 or 1.
    eps = 1e-5
    move_probs = np.clip(move_probs, eps, 1 - eps)
    move_probs = move_probs / np.sum(move_probs)
    candidates = np.arange(num_moves)
    ranked_moves = np.random.choice(candidates, num_moves, replace = False, p = move_probs)
    for point_idx in ranked_moves:
      point = self.encoder.decode_point_index(point_idx)
      if game_state.is_valid_move(Move.play(point)):
        if self.collector is not None:
          self.collector.record_decision(state=board_tensor, action=point_idx)
        return Move.play(point)

  def train(self, experience, learning_rate, clipnorm, batch_size):
    self.model.compile(loss='categorical_crossentropy', optimizer=SGD(learning_rate=learning_rate, clipnorm=clipnorm))
    target_vectors = prepare_experience_data(experience, self.encoder.board_width, self.encoder.board_height)
    self.model.fit(experience.states, target_vectors, batch_size=batch_size, epochs=1)
    
  def serialize(self, h5file):
    h5file.create_group('encoder')
    h5file['encoder'].attrs['name'] = self.encoder.name()
    h5file.create_group('model')
    utils.save_model_to_hdf5_group(self.model, h5file['model'])

# make Experience suitable for keras.fit
def prepare_experience_data(experience, board_width, board_height):
  experience_size = experience.actions.shape[0]
  target_vectors = np.zeros((experience_size, board_width * board_height))
  for i in range(experience_size):
    action = experience.actions[i]
    reward = experience.rewards[i]
    target_vectors[i][action] = reward
  return target_vectors


class IndexError(Exception):
  pass


class QAgent(Agent):
  def __init__(self, model, encoder):
    self.model = model
    self.encoder = encoder
    self.collector = None
    self.temperature = 0.0
#    self.last_move_value = 0

  def set_temperature(self, temperature):
    self.temperature = temperature

  def set_collector(self, collector):
    self.collector = collector

  def select_move(self, game_state):
    board_tensor = self.encoder.encode(game_state)

    moves = []
    board_tensors = []
    for move in game_state.legal_moves():
      if not move.is_play:
        continue
      moves.append(self.encoder.encode_point(move.point))
      board_tensors.append(board_tensor)
    if not moves:
      raise NotImplementedError() # never should happen

    num_moves = len(moves)
    board_tensors = np.array(board_tensors)
    move_vectors = np.zeros( (num_moves, self.encoder.num_points()) )
    for i, move in enumerate(moves):
      move_vectors[i][move] = 1

    values = self.model.predict( [board_tensors, move_vectors] )
    values = values.reshape(len(moves))

    ranked_moves = self.rank_moves_eps_greedy(values)

    for move_idx in ranked_moves:
      point = self.encoder.decode_point_index(moves[move_idx])
      if self.collector is not None:
        self.collector.record_decision(state=board_tensor, action=moves[move_idx])
      return Move.play(point)


  def train(self, experience, learning_rate=0.1, batch_size=128):
    opt = SGD(learning_rate=learning_rate)
    self.model.compile(loss='mse', optimizer=opt)

    n = experience.states.shape[0]
    num_moves = self.encoder.num_points()
    y = np.zeros((n,))
    actions = np.zeros((n, num_moves))
    for i in range(n):
      action = experience.actions[i]
      reward = experience.rewards[i]
      actions[i][action] = 1
      y[i] = reward
    self.model.fit( [experience.states, actions], y, batch_size=batch_size, epochs=1)

  def rank_moves_eps_greedy(self, values):
    if np.random.random() < self.temperature:
      values = np.random.random(values.shape)
    # This ranks the moves from worst to best.
    ranked_moves = np.argsort(values)
    # Return them in best-to-worst order.
    return ranked_moves[::-1]

  def serialize(self, h5file):
    raise NotImplementedError()

  def diagnostics(self):
    return {'value': self.last_move_value}


class ACAgent(Agent):
  def __init__(self, model, encoder):
    self.model = model
    self.encoder = encoder
    self.collector = None
    # self.last_state_value = 0

  def set_collector(self, collector):
    self.collector = collector

  def select_move(self, game, verbose=False):
    num_moves = self.encoder.board_width * self.encoder.board_height
    board_tensor = self.encoder.encode(game)
    X = np.array([board_tensor])

    actions, values = self.model(X)
    move_probs = actions[0]
    estimated_value = values[0][0]
    self.last_move_value = float(estimated_value)

    # for rr in range(6):
    #   for cc in range(13):
    #     print(f"{move_probs[13*rr + cc]:.3f} ", end="")
    #   print(" ")

    eps = 1e-6
    move_probs = np.multiply(board_tensor[3].flatten(), move_probs)
    move_probs = np.clip(move_probs, eps, 1 - eps)
    move_probs = move_probs / np.sum(move_probs)
    candidates = np.arange(num_moves)
    ranked_moves = np.random.choice(candidates, num_moves, replace=False, p=move_probs)

    for point_idx in ranked_moves:
      point = self.encoder.decode_point_index(point_idx)
      move = Move.play(point)
      if game.is_valid_move(move):

        # Plot heatmaps
        if verbose:
          for idx in [0, 3, 4, 5, 6, 7, 8, 9, 12, 52, 64, 65, 66, 67, 75, 76, 77]:
            move_probs[idx] = np.nan
          heatmap = move_probs.reshape((6, 13))
          fig, ax = plt.subplots()
          im = ax.imshow(heatmap)
          ax.spines['top'].set_visible(False)
          ax.spines['right'].set_visible(False)
          ax.spines['bottom'].set_visible(False)
          ax.spines['left'].set_visible(False)
          ax.set_title(f"{game.current_player} to move\nChosen moves: {ranked_moves[0:6]}\nActual move: {point_idx}\nEstimated value: {estimated_value}")
          for i in range(6):
              for j in range(13):
                  if board_tensor[3][i][j] > 0:
                    _text = ax.text(j, i, 13*i+j, ha="center", va="center", color="w")
          fig.tight_layout()
          plt.show()
        
        if self.collector is not None:
          self.collector.record_decision(state=board_tensor, action=point_idx, estimated_value=estimated_value)
        return move
    raise ValueError


  def serialize(self, h5file):
    raise NotImplementedError()

  def diagnostics(self):
    return {'value': self.last_move_value}

