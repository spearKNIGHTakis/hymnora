import React from 'react';
import {Music2} from 'lucide-react';
import {statusLabel} from './domain';
export const IconButton=({label,children,...props})=><button className="icon-button" aria-label={label} title={label} {...props}>{children}</button>;
export const Badge=({status})=><span className={`badge ${status}`}><i/>{statusLabel(status)}</span>;
export function Brand(){return <div className="brand"><Music2 size={38}/><span>Hymnora<br/>Studio</span></div>;}
