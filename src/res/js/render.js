import { ApplyDefaults } from './defaults.js'
import { Scaler } from './scaler.js'
import { RenderTitle } from './title.js'
import { RenderGridLines } from './gridlines.js'
import { RenderIcons } from './icons.js'
import { RenderConnections } from './connections.js'
import { RenderGroups } from './groups.js'
import { RenderNotes } from './notes.js'
import { ExtractColorAndOpacity } from './common.js'

export function Render(containerSelector, doc, keepZoom, enableZoom = true) {
    ApplyDefaults(doc);
    
    // Save the current zoom transform if keepZoom is true
    let initialZoom = d3.zoomIdentity;
    if(keepZoom && d3.select(`${containerSelector} svg`).node() != null)
    {
        initialZoom = d3.zoomTransform(d3.select(`${containerSelector} svg`).node());
    }

    d3.select(`${containerSelector} > svg`).remove();

    let containerBox = d3.select(containerSelector).node().getBoundingClientRect();

    let dataBag = {};

    if (doc.document.aspectRatio == null || doc.document.aspectRatio == "none" || doc.document.aspectRatio == "auto") {
        dataBag.AvailableHeight = containerBox.height - doc.document.margin.top - doc.document.margin.bottom;
        dataBag.AvailableWidth = containerBox.width - doc.document.margin.left - doc.document.margin.right;
        dataBag.HCenterOffset = 0;
        dataBag.VCenterOffset = 0;
    }
    else {
        let maxAvailalbeHeight = containerBox.height - doc.document.margin.top - doc.document.margin.bottom;
        let maxAvailableWidth = containerBox.width - doc.document.margin.left - doc.document.margin.right;

        let aspectRatio = doc.document.aspectRatio.split(':');
        aspectRatio = aspectRatio[0] / aspectRatio[1];

        let heightByWidth = maxAvailableWidth / aspectRatio;
        let widthByHeight = maxAvailalbeHeight * aspectRatio;

        if (heightByWidth > maxAvailalbeHeight) {
            dataBag.AvailableHeight = maxAvailalbeHeight;
            dataBag.AvailableWidth = widthByHeight;
            dataBag.HCenterOffset = (maxAvailableWidth - widthByHeight) / 2;
            dataBag.VCenterOffset = 0;
        }
        else {
            dataBag.AvailableHeight = heightByWidth;
            dataBag.AvailableWidth = maxAvailableWidth;
            dataBag.HCenterOffset = 0;
            dataBag.VCenterOffset = (maxAvailalbeHeight - heightByWidth) / 2;
        }
    }

    let mainContainer = d3.select(containerSelector)
        .append("svg")
        .attr("class", "render")
        .attr("width", containerBox.width)
        .attr("height", containerBox.height);

    let { color: bgColor, opacity: bgOpacity } = ExtractColorAndOpacity(doc.document.fill);
    mainContainer.style("background-color", bgColor);
    if (bgOpacity !== null) {
        mainContainer.style("opacity", bgOpacity);
    }

    let zoomContainer = mainContainer.append("g")
        .attr("class", "zoom");

    // Create zoom behavior after zoomContainer is defined
    let zoom = d3.zoom().on("zoom", function (e) {
        zoomContainer.attr("transform", e.transform);
        document.querySelectorAll(".render .metadata").forEach(function (element) {
            let evt = new Event('mouseleave');
            element.dispatchEvent(evt);
        });

        // Dispatch zoom change event
        d3.select(containerSelector).node().dispatchEvent(new CustomEvent("zoomchange", { detail: e.transform }));
    });

    if (enableZoom) {
        // Apply zoom behavior to the main container
        mainContainer.call(zoom);
        mainContainer.node().__zoomBehavior = zoom;

        // Apply the saved zoom transform if keepZoom was true
        if (keepZoom && initialZoom && (initialZoom.k !== 1 || initialZoom.x !== 0 || initialZoom.y !== 0)) {
            mainContainer.call(zoom.transform, initialZoom);
        }
    }

    let documentContainer = zoomContainer.append("g")
        .attr("transform", `translate(${doc.document.margin.left + dataBag.HCenterOffset}, ${doc.document.margin.top + dataBag.VCenterOffset})`)
        .attr("class", "document");

    RenderTitle(documentContainer, doc, dataBag);

    if (dataBag.TitleRendered) {
        dataBag.DiagramHeight = dataBag.AvailableHeight - dataBag.TitleHeight - doc.diagram.padding.top - doc.diagram.padding.bottom;
        dataBag.DiagramWidth = dataBag.AvailableWidth - doc.diagram.padding.left - doc.diagram.padding.right;
    }
    else {
        dataBag.DiagramHeight = dataBag.AvailableHeight - doc.diagram.padding.top - doc.diagram.padding.bottom;
        dataBag.DiagramWidth = dataBag.AvailableWidth - doc.diagram.padding.left - doc.diagram.padding.right;
    }

    dataBag.Scaler = {}
    dataBag.Scaler.X = new Scaler(0, doc.diagram.columns - 1, 0, dataBag.DiagramWidth, 1);
    if (doc.diagram.invertY) {
        dataBag.Scaler.Y = new Scaler(0, doc.diagram.rows - 1, dataBag.DiagramHeight, 0, 1);
    }
    else {
        dataBag.Scaler.Y = new Scaler(0, doc.diagram.rows - 1, 0, dataBag.DiagramHeight, 1);
    }

    let diagramContainer = documentContainer.append("g");
    if (doc.title.position == "top") {
        diagramContainer.attr("transform", `translate(${doc.diagram.padding.left}, ${doc.diagram.padding.top + dataBag.TitleHeight})`);
    }
    else {
        diagramContainer.attr("transform", `translate(${doc.diagram.padding.left}, ${doc.diagram.padding.top})`);
    }


    RenderGridLines(diagramContainer, doc, dataBag);
    RenderIcons(diagramContainer, doc, dataBag);
    RenderNotes(diagramContainer, doc, dataBag);
    RenderGroups(diagramContainer, doc, dataBag);
    RenderConnections(diagramContainer, doc, dataBag);

    if (doc.document.watermark) {
        let watermarkContainer = documentContainer.append("g")
            .attr("transform", `translate(${dataBag.AvailableWidth / 2}, ${dataBag.AvailableHeight})`);

        watermarkContainer.append("text")
            .attr("text-anchor", "middle")
            .append("a")
            .attr("xlink:href", "https://DrawTheNet.IO")
            .attr("class", "watermark")
            .attr("target", "_blank")
            .text("Created with DrawTheNet.IO");
    }


    // Order : grid, groups, connections, notes, icons
    BringForward(diagramContainer, '.grids');
    BringForward(diagramContainer, '.groups');
    BringForward(diagramContainer, '.connections');
    BringForward(diagramContainer, '.notes');
    BringForward(diagramContainer, '.icons');

    // then all labels
    BringForward(diagramContainer, '.icon-label');
    BringForward(diagramContainer, '.connection-label');
    BringForward(diagramContainer, '.group-label');

    // then watermark
    BringForward(documentContainer, '.watermark');
}

function BringForward(container, selector) {
    container.selectAll(selector).each(function (d) {
        d3.select(this).each(function () {
            this.parentNode.appendChild(this);
        });
    });
}