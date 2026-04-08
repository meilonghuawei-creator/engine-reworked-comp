extends Node

var Players = {}
var LobbyMembers = {}

func reorder_playernumbers():
	var a = 1
	for i in Players:
		Players[i].playernum = a
		a = a + 1

@rpc("any_peer","call_local","reliable")
func add_late_joiner():
	pass
