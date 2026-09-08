"use client";
import { ColorMatchPanel, type PhotoReview } from '../color-match/page';
export default function Po4ColorMatch() {
  return <Po4ColorMatchPanel onReview={review=>{
    const state=JSON.parse(localStorage.getItem('reef-demo-state-v10')??'{}');
    sessionStorage.setItem('reef-photo-review',JSON.stringify({review,tankId:state.tankId??null}));
    // eslint-disable-next-line @next/next/no-location-assign-relative-destination -- The session handoff must load the home page and its tank state together.
    window.location.assign('/');
  }}/>;
}
export function Po4ColorMatchPanel(props:{onReview?: (review:PhotoReview)=>void;onClose?:()=>void}) {
  return <ColorMatchPanel {...props} parameterId="po4"/>;
}
