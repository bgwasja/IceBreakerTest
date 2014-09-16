class Conversation < ActiveRecord::Base
  belongs_to :sender, class_name: User, foreign_key: :sender_id
  belongs_to :receiver, class_name: User, foreign_key: :receiver_id
  belongs_to :mute
  before_create :attr_by_default
  before_update :mute_users
  validates_presence_of :sender_id, :receiver_id

  def attr_by_default
    self.initial_viewed = false
    self.reply_viewed = false
    self.finished_viewed = false
    nil
  end

  def mute_users
    if self.finished_changed?
      mute = self.mutes.new(sender_id: self.sender_id, receiver_id: self.receiver_id, conversation_id: self.id)
      mute.save
      scheduler = Rufus::Scheduler.new
      scheduler.at Time.now + 1.hours do
        Mute.find_by_id(mute.id).destroy
      end
    end
  end

  def ignore_user sender_id, receiver_id
    ignore = self.mutes.new(sender_id: sender_id, receiver_id: receiver_id, conversation_id: self.id)
    ignore.save
    scheduler = Rufus::Scheduler.new
    scheduler.at Time.now + 4.hours do
      Mute.find_by_id(ignore.id).destroy
    end
  end

  def to_json(current_user)
    {
        sender: sender_for_json(current_user),
        last_message: last_message_for_json
    }.merge(conversation_status_for_json(current_user))
  end

  def sender_for_json(current_user)
    {sender_id: sender_identity.id,
     first_name: sender_identity.first_name,
     last_name: sender_identity.last_name,
     user_avatar: receiver_avatar(current_user)  }
  end

  def last_message_for_json
    {sender_id: sender_identity.id,
     text: last_message,
     status: status}
  end

  def conversation_status_for_json(current_user)
    {blocked_to: blocked_to(current_user),
     conversation_id: self.id,
     updated_at: self.updated_at}
  end

  def last_message
    if self.finished.nil?
      self.reply
    else
      self.finished
    end
  end

  def status
    if self.finished.nil?
      'reply'
    elsif self.reply.nil?
      'initial'
    else
      'finished'
    end
  end

  def blocked_to(current_user)
    if self.mute
      if current_user != self.mute.sender_id
        self.mute.receiver_id
      elsif current_user != self.mute.receiver_id
        self.mute.sender_id
      end
    else
      'No'
    end
  end

  def ignored
    if Mute.find_by_conversation_id(self.id)
      true
    else
      false
    end
  end

  def sender_identity
    if self.finished.nil?
      @companion ||= User.find(self.receiver_id)
    else
      @companion ||= User.find(self.sender_id)
    end
  end

  def receiver_avatar(current_user)
    friend_id = [sender_id,receiver_id].select{|id| id != current_user}
    @user_avatar ||= User.find(friend_id).first.avatar.url
  end


end
