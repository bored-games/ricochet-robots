Players can change nicknames on top of an automatically generated (string) username.

**Backend → Frontend**

- [x] connect_to_server (shares room name?)
- [x] update_board (gives the boundary board)
- [x] update_robots (gives robot positions at start or after simulating a set of moves)
- [x] update_goals (gives all goal positions and the one active goal)
- [x] update_scoreboard (gives a list of all room users and their scores)
- [x] update_user (gives information about self user)
- [x] switch_to_countdown (signals a solution has been found)
- [x] switch_to_timer (signals a new round beginning)
- [x] clear_moves_queue (forces clear move (e.g. at new round))
- [x] player_chat_new_message (player chat to all)
- [x] system_chat_new_message (system chat to all)
- [x] system_chat_to_player_new_message (system chat to individual player)
- [x] system_chat_svg (special system message containing a solution SVG url)


**Frontend → Backend**

- [x] ping
- [x] get_user (query if info is needed)
- [x] update_user (set new name, color)
- [x] update_chat (send a message)
- [x] game_action
    - [x] submit_movelist
    - [ ] new_game (fe needed)
    