# frozen_string_literal: true

module Engine
  module Game
    module GRotla
      module Step
        class Merger < Engine::Step::Base
          def setup
            @declined = []
          end

          def description
            return "#{@major.name}: discard excess trains" if @major
            return "#{@president.name}: choose the new major" if @president
            return "#{@target.owner.name}: consent to #{source.name} / #{@target.name} merger" if @target

            "#{source&.name}: propose a merger or pass"
          end

          def source
            @round.entities[@round.entity_index]
          end

          def merge_target
            @major || source
          end

          def mergeable(_entity)
            @target && !@major ? [@target] : []
          end

          def show_other_players
            true
          end

          def active_entities
            [@major&.owner || @president || @target&.owner || source&.owner].compact
          end

          def actions(entity)
            return [] if entity != current_entity || !source

            @target || @major ? ['choose'] : %w[choose pass]
          end

          def choice_name
            description
          end

          def choices
            if @major
              @major.trains.reject(&:rusted).to_h { |train| ["discard:#{train.id}", "Discard #{train.name} train (#{train.id})"] }
            elsif @president
              @game.available_majors.flat_map do |major|
                [["major:#{major.id}", "Form #{major.full_name}"],
                 ["major:#{major.id}:alternate", "Form #{Economy::MAJOR_ALTERNATE_NAMES.fetch(major.id)}"]]
              end.to_h
            elsif @target
              { 'accept' => 'Agree to merger', 'decline' => 'Decline merger' }
            else
              return {} if @game.available_majors.empty?

              targets = @game.operating_order.select do |target|
                target.type == :minor && target != source && !@declined.include?(pair(source, target)) &&
                  @game.merger_connected?(source, target)
              end
              targets.to_h { |target| ["merge:#{target.id}", "Propose merger with #{target.name} (#{target.owner.name})"] }
            end
          end

          def process_choose(action)
            raise GameError, 'Choose an available merger option' unless choices.key?(action.choice)

            if @major
              train = @major.trains.find { |candidate| "discard:#{candidate.id}" == action.choice }
              @log << "#{@major.name} discards its #{train.name} train to the bank pool"
              @game.depot.reclaim_train(train)
              advance! unless excess_trains?
            elsif @president
              _, id, side = action.choice.split(':')
              @major = @game.merge_minors!(source, @target, @game.corporation_by_id(id), alternate: side == 'alternate')
              advance! unless excess_trains?
            elsif @target
              if action.choice == 'accept'
                @president = @game.merger_president(source, @target)
              else
                @declined << pair(source, @target)
                @log << "#{action.entity.name} declines the #{source.name} / #{@target.name} merger"
                advance!
              end
            else
              @target = @game.corporation_by_id(action.choice.delete_prefix('merge:'))
              @log << "#{action.entity.name} proposes merging #{source.name} with #{@target.name}"
              @president = @game.merger_president(source, @target) if source.owner == @target.owner
            end
          end

          def process_pass(action)
            log_pass(action.entity)
            advance!
          end

          def excess_trains?
            @game.num_corp_trains(@major) > @game.train_limit(@major)
          end

          def pair(first, second)
            [first.id, second.id].sort
          end

          def advance!
            @major = @president = @target = nil
            @round.entity_index += 1
            @round.entity_index += 1 while source&.closed?
            @game.next_turn!
            pass! unless source
          end
        end

        class ExportDiscard < Engine::Step::Base
          def description
            'Discard excess trains after the export phase change'
          end

          def actions(entity)
            entity == current_entity ? ['choose'] : []
          end

          def choice_name
            description
          end

          def choices
            current_entity.trains.reject(&:rusted).to_h do |train|
              ["discard:#{train.id}", "Discard #{train.name} train (#{train.id})"]
            end
          end

          def process_choose(action)
            raise GameError, 'Choose an excess train to discard' unless choices.key?(action.choice)

            train = action.entity.trains.find { |candidate| "discard:#{candidate.id}" == action.choice }
            @game.depot.reclaim_train(train)
            @log << "#{action.entity.name} discards its #{train.name} train to the bank pool"
            return if @game.num_corp_trains(action.entity) > @game.train_limit(action.entity)

            @round.entity_index += 1
            @game.next_turn!
            pass! unless @round.entities[@round.entity_index]
          end
        end
      end
    end
  end
end
