import './app.css';
import './styles/shell.css';
import './styles/audio.css';
import './styles/experiments.css';
import './styles/tools.css';
import { start } from '../build/dev/javascript/ulik/ulik.mjs';

// The same Lustre views are prerendered. Start fresh to attach event handlers.
document.getElementById('app').replaceChildren();
start(location.href, __APP_VERSION__);
