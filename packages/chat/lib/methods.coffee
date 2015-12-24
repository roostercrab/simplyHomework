Meteor.methods
	###*
	# @method createPrivateChatRoom
	# @param {String} userId
	# @return {String} The ID of the newely created ChatRoom.
	###
	createPrivateChatRoom: (userId) -> # TODO: See why this can create multiple chatrooms between the same users.
		check userId, String
		if (val = ChatRooms.findOne users: [@userId, userId])?
			val._id
		else
			chatRoom = new ChatRoom @userId, 'private'
			chatRoom.users.push userId
			ChatRooms.insert chatRoom

	###*
	# @method addChatMessage
	# @param {String} content
	# @param {String} chatRoomId
	# @return {String} The ID of the added chatMessage.
	###
	addChatMessage: (content, chatRoomId) ->
		check content, String
		check chatRoomId, String

		content = content.trim()
		if content.length is 0
			throw new Meteor.Error 'message-empty'

		if ChatRooms.find(_id: chatRoomId, users: @userId).count() is 0
			throw new Meteor.Error 'not-in-room'

		ChatRooms.update chatRoomId, $set: lastMessageTime: new Date
		ChatMessages.insert new ChatMessage content, @userId, chatRoomId

	###*
	# @method updateChatMessage
	# @param {String} content
	# @param {String} chatMessageId
	###
	updateChatMessage: (content, chatMessageId) ->
		check content, String
		check chatMessageId, String

		content = content.trim()
		if content.length is 0
			throw new Meteor.Error 'message-empty'

		old = ChatMessages.findOne
			_id: chatMessageId
			creatorId: @userId
		if not old?
			throw new Meteor.Error 'invalid-id'
		else if old.content is content
			throw new Meteor.Error 'same-content'

		ChatMessages.update chatMessageId,
			$set:
				content: content
				changedOn: new Date
		undefined

	###*
	# Marks unread ChatMessages as read.
	# @method markChatMessagesRead
	# @param {String} chatRoomid The ID of the ChatRoom.
	###
	markChatMessagesRead: (chatRoomId) ->
		@unblock()
		check chatRoomId, String

		ChatMessages.update {
			chatRoomId: chatRoomId
			readBy: $ne: @userId
		}, {
			$push: readBy: @userId
		}, {
			multi: yes
		}