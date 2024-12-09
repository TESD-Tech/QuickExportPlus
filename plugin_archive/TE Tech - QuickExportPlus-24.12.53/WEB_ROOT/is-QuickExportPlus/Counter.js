import { d as delegate, c as create_custom_element, a as append_styles, p as prop, f as first_child, s as slot, t as template_effect, b as append, e as pop, g as set, h as get, i as template, j as state, k as flush_sync, l as push, m as sibling, n as child, r as reset, o as set_class, q as set_text } from './custom-element.js';

const increment = (_, count) => {
	set(count, get(count) + 1);
};

var root = template(`<button> </button> <!>`, 1);

const $$css = {
	hash: "svelte-10nnoa",
	code: "button.svelte-10nnoa {padding:10px;color:#fff;font-size:17px;border-radius:5px;border:1px solid #ccc;cursor:pointer;}.btn-solid.svelte-10nnoa {background:#20c997;border-color:#4cae4c;}.btn-outline.svelte-10nnoa {color:#20c997;background:transparent;border-color:#20c997;}"
};

function Counter($$anchor, $$props) {
	push($$props, true);
	append_styles($$anchor, $$css);

	/**
	 * @typedef {Object} Props
	 * @property {string} [type] - Component props
	 */
	/** @type {Props} */
	let type = prop($$props, "type", 7, "solid");
	let count = state(0);
	var fragment = root();
	var button = first_child(fragment);

	button.__click = [increment, count];

	var text = child(button);

	reset(button);

	var node = sibling(button, 2);

	slot(node, $$props, "default", {}, null);

	template_effect(() => {
		set_class(button, `${(type() == "solid" ? "btn-solid" : "btn-outline") ?? ""} svelte-10nnoa`);
		set_text(text, `count is ${get(count) ?? ""}`);
	});

	append($$anchor, fragment);

	return pop({
		get type() {
			return type();
		},
		set type($$value = "solid") {
			type($$value);
			flush_sync();
		}
	});
}

delegate(["click"]);
customElements.define("ps-svelte-counter", create_custom_element(Counter, { type: {} }, ["default"], [], true));
