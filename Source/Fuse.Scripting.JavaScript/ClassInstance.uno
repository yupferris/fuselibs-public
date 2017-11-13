using Uno;
using Uno.UX;
using Uno.Collections;

namespace Fuse.Scripting.JavaScript
{
	class EventProxyEventArgs : EventArgs, IScriptEvent
	{
		readonly Dictionary<string, object> _args;

		public EventProxyEventArgs(Dictionary<string, object> args)
		{
			_args = args;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			foreach (var a in _args)
				s.AddObject(a.Key, a.Value);
		}
	}

	// TODO: Name, separate file, ..
	class EventProxy
	{
		readonly ThreadWorker _worker;
		readonly Scripting.Object _obj;
		readonly Uno.UX.Event _event;

		public EventProxy(ThreadWorker worker, Scripting.Object obj, Uno.UX.Event e, Scripting.Context context)
		{
			_worker = worker;
			_obj = obj;
			_event = e;

			// TODO
			var fn = (Function)context.Evaluate("(EventProxy)", // TODO
				"(function(instance, callback) {"
					+ "instance." + e.Name + " = callback;"
				+ "})");
			fn.Call(context, _obj, (Callback)Raise);
		}

		// TODO: This name is not at all clear/consistent
		public void Reset()
		{
			// TODO
		}

		object Raise(Scripting.Context context, object[] args)
		{
			if (args.Length == 0)
			{
				_event.Raise(this, new EventProxyEventArgs(new Dictionary<string, object>()));
				return null;
			}

			if (args.Length > 1)
			{
				Fuse.Diagnostics.UserError("ux:Events must be raised from JavaScript with zero arguments, or one argument defining the arguments to the event", args);
				return null;
			}

			var obj = args[0] as Scripting.Object;
			if (obj == null)
			{
				Fuse.Diagnostics.UserError("ux:Events must be raised with a JavaScript object to define name/value pairs", args[0]);
				return null;
			}

			var keys = obj.Keys;
			var evArgs = new Dictionary<string, object>();
			for (int i = 0; i < keys.Length; i++)
			{
				var name = keys[i];
				evArgs[name] = obj[name];
			}

			_event.Raise(this, new EventProxyEventArgs(evArgs));

			return null;
		}
	}

	/** Manages the lifetime of a UX class instance's representation in JavaScript modules
		within the class, dealing with disposal of resources when the related node is unrooted.
	*/
	class ClassInstance
	{
		readonly ThreadWorker _worker;
		readonly NameTable _rootTable;
		readonly object _obj;
		Scripting.Object _self;
		Dictionary<Uno.UX.Property, ObservableProperty> _properties;
		Dictionary<Uno.UX.Event, EventProxy> _events;

		internal ObservableProperty GetObservableProperty(string name)
		{
			if (_properties != null)
				foreach (var p in _properties.Values)
					if (p.Name == name) return p;
			return null;
		}

		/** Should only be called by ThreadWorker.
			To retrieve an instance, use ThreadWorker.GetClassInstance()
		 */
		internal ClassInstance(ThreadWorker context, object obj, NameTable rootTable)
		{
			_worker = context;
			_rootTable = rootTable;
			_obj = obj;
		}

		/** Calls a function on this node instance, making the node 'this' within the function */
		public void CallMethod(Scripting.Context context, Scripting.Function method, object[] args)
		{
			// TODO: Rewrite to use Function.apply() to avoid leaking this member
			_self["_tempMethod"] = method;
			_self.CallMethod(context, "_tempMethod", args);
		}

		/** Called on JS thread when the node instance must be rooted. */
		public void EnsureRooted(Scripting.Context context)
		{
			if (_self != null) return;

			var n = _obj as INotifyUnrooted;
			if (n != null) n.Unrooted += DispatchUnroot;

			_self = context.Unwrap(_obj) as Scripting.Object;

			if (_properties == null)
			{
				if (_rootTable != null)
				{
					EnsureHasProperties();
					for (int i = 0; i < _rootTable.Properties.Count; i++)
					{
						var p = _rootTable.Properties[i];
						if (!_properties.ContainsKey(p))
							_properties.Add(p, new LazyObservableProperty(_worker, _self, p, context));
					}
				}
			}

			if (_events == null)
			{
				if (_rootTable != null)
				{
					_events = new Dictionary<Uno.UX.Event, EventProxy>();
					for (int i = 0; i < _rootTable.Events.Count; i++)
					{
						var e = _rootTable.Events[i];
						_events.Add(e, new EventProxy(_worker, _self, e, context));
					}
				}
			}
		}

		void EnsureHasProperties()
		{
			if (_properties == null) _properties = new Dictionary<Uno.UX.Property, ObservableProperty>();
		}

		void DispatchUnroot()
		{
			var n = (INotifyUnrooted)_rootTable.This;
			n.Unrooted -= DispatchUnroot;
			_worker.Invoke(Unroot);
		}

		internal Scripting.Object GetPropertyObservable(Scripting.Context context, Uno.UX.Property p)
		{
			EnsureHasProperties();

			ObservableProperty op;
			if (!_properties.TryGetValue(p, out op))
			{
				op = new ObservableProperty(_worker, _self, p);
				_properties.Add(p, op);
			}
			return op.GetObservable(context).Object;
		}

		void Unroot(Scripting.Context context)
		{
			if (_self == null) return;

			// TODO: Should we be disposing of/clearing the _properties collection here? From what I can tell this is not safe if we root again
			if (_properties != null)
			{
				foreach (var p in _properties.Values)
				{
					p.Reset();
				}
			}

			// TODO: Look into disposing of/clearing _events collection
			if (_events != null)
			{
				foreach (var e in _events.Values)
				{
					e.Reset();
				}
			}

			_self = null;
		}
	}
}
