require 'spec_helper'

RSpec.describe JsonapiCompliable do
  let(:klass) do
    Class.new do
      attr_accessor :params
      include JsonapiCompliable::Base

      jsonapi do
        type :authors
      end

      def params
        @params || {}
      end
    end
  end

  let(:instance) { klass.new }

  describe '.jsonapi' do
    let(:subclass1) do
      Class.new(klass) do
        jsonapi do
          type :subclass_1
          allow_filter :id
          allow_filter :foo
        end
      end
    end

    let(:subclass2) do
      Class.new(subclass1) do
        jsonapi do
          type :subclass_2
          allow_filter :foo do |scope, value|
            'foo'
          end
        end
      end
    end

    it 'assigns a subclass of Resource by default' do
      expect(klass._jsonapi_compliable.ancestors)
        .to include(JsonapiCompliable::Resource)
      expect(klass._jsonapi_compliable.object_id)
        .to_not eq(JsonapiCompliable::Resource.object_id)
    end

    context 'when subclassing and customizing' do
      def config(obj)
        obj._jsonapi_compliable.config
      end

      it 'preserves values from superclass' do
        expect(config(subclass2)[:filters][:id]).to_not be_nil
      end

      it 'does not alter superclass when overriding' do
        expect(config(subclass1)).to_not eq(config(subclass2))
        expect(config(subclass1)[:filters][:id].object_id)
          .to_not eq(config(subclass2)[:filters][:id].object_id)
        expect(config(subclass1)[:filters][:foo][:filter]).to be_nil
        expect(config(subclass2)[:filters][:foo][:filter]).to_not be_nil
      end

      it 'overrides type for subclass' do
        expect(config(subclass2)[:type]).to eq(:subclass_2)
        expect(config(subclass1)[:type]).to eq(:subclass_1)
      end
    end
  end

  describe '#wrap_context' do
    before do
      allow(instance).to receive(:action_name) { 'index' }
    end

    it 'wraps in the resource context' do
      instance.wrap_context do
        expect(instance.resource.context).to eq({
          object: instance,
          namespace: :index
        })
      end
    end

    context 'when the class does not have a resource' do
      let(:klass) do
        Class.new do
          include JsonapiCompliable
        end
      end

      it 'does nothing' do
        instance.wrap_context do
          expect(instance.resource).to be_nil
        end
      end
    end
  end

  describe '#render_jsonapi' do
    before do
      allow(instance).to receive(:force_includes?) { false }
    end

    it 'is able to override options' do
      author = Author.create!(first_name: 'Stephen', last_name: 'King')
      author.books.create(title: "The Shining", genre: Genre.new(name: 'horror'))

      expect(instance).to receive(:perform_render_jsonapi).with(hash_including(meta: { foo: 'bar' }))
      instance.render_jsonapi(Author.all, { scope: false, meta: { foo: 'bar' } })
    end

    context 'when passing scope: false' do
      it 'does not appy jsonapi_scope' do
        instance.params = { include: 'books.genre,foo' }
        author = double
        allow(Author).to receive(:all).and_return([author])
        expect(Author).to_not receive(:find_by_sql)
        expect(author).to_not receive(:includes)
        expect(instance).to_not receive(:jsonapi_scope)

        instance.render_jsonapi(Author.all, scope: false)
      end
    end
  end
end
